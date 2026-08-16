"""
Rule-based notification generator (Section 17). There's no background
scheduler in this codebase, so `run_all_rules()` is designed to be called
either from the `/notifications/generate` endpoint (useful for manual
testing and for wiring into an external cron/Celery-beat job) or directly
from a future scheduler. Each rule is idempotent: it skips creating a
notification if an equivalent unread one already exists, so calling this
repeatedly (e.g. every few minutes) doesn't spam duplicates.
"""
from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.identity import User, Role
from app.models.business import Vehicle, BusinessUnit, Property
from app.models.financial import MaintenanceRecord, RentalTransaction
from app.models.shop import Product
from app.models.support import Notification
from app.services.financial_calculator import total_expense, total_revenue

DECISION_MAKER_ROLES = ("super_admin", "manager")


def _decision_maker_ids(db: Session) -> list:
    rows = db.execute(
        select(User.id).join(Role, Role.id == User.role_id).where(
            Role.name.in_(DECISION_MAKER_ROLES), User.active.is_(True), User.deleted_at.is_(None)
        )
    ).all()
    return [r[0] for r in rows]


def _notify_if_new(db: Session, user_id, notif_type: str, title: str, body: str) -> bool:
    existing = db.execute(
        select(Notification).where(
            Notification.user_id == user_id,
            Notification.type == notif_type,
            Notification.title == title,
            Notification.is_read.is_(False),
        )
    ).scalar_one_or_none()
    if existing is not None:
        return False
    db.add(Notification(user_id=user_id, type=notif_type, title=title, body=body))
    return True


def check_rent_due_and_overdue(db: Session) -> int:
    created = 0
    today = date.today()
    this_month = today.replace(day=1)
    recipients = _decision_maker_ids(db)

    outstanding = db.execute(
        select(RentalTransaction, Property, BusinessUnit)
        .join(Property, Property.id == RentalTransaction.property_id)
        .join(BusinessUnit, BusinessUnit.id == Property.business_unit_id)
        .where(RentalTransaction.status.in_(["outstanding", "partial"]))
    ).all()

    for rt, prop, unit in outstanding:
        balance = float(rt.amount_due) - float(rt.amount_paid)
        if balance <= 0:
            continue
        is_overdue = rt.period_month < this_month
        notif_type = "rent_overdue" if is_overdue else "rent_due"
        title = f"{'Overdue' if is_overdue else 'Due'} rent: {unit.name} ({rt.period_month.strftime('%Y-%m')})"
        body = f"ETB {balance:,.2f} outstanding for {unit.name}, period {rt.period_month.strftime('%Y-%m')}."
        for user_id in recipients:
            if _notify_if_new(db, user_id, notif_type, title, body):
                created += 1
    return created


def check_vehicle_maintenance_due(db: Session, lookahead_days: int = 7) -> int:
    created = 0
    today = date.today()
    horizon = today + timedelta(days=lookahead_days)
    recipients = _decision_maker_ids(db)

    due = db.execute(
        select(MaintenanceRecord, BusinessUnit)
        .join(BusinessUnit, BusinessUnit.id == MaintenanceRecord.business_unit_id)
        .where(MaintenanceRecord.next_due.is_not(None), MaintenanceRecord.next_due <= horizon,
               MaintenanceRecord.next_due >= today)
    ).all()

    for record, unit in due:
        title = f"Maintenance due: {unit.name} ({record.next_due.isoformat()})"
        body = f"{unit.name} has maintenance due on {record.next_due.isoformat()}: {record.description or 'scheduled service'}."
        for user_id in recipients:
            if _notify_if_new(db, user_id, "vehicle_maintenance", title, body):
                created += 1
    return created


def check_vehicle_document_expiry(db: Session, lookahead_days: int = 30) -> int:
    created = 0
    today = date.today()
    horizon = today + timedelta(days=lookahead_days)
    recipients = _decision_maker_ids(db)

    vehicles = db.execute(
        select(Vehicle, BusinessUnit).join(BusinessUnit, BusinessUnit.id == Vehicle.business_unit_id)
    ).all()

    for vehicle, unit in vehicles:
        if vehicle.insurance_expiry and today <= vehicle.insurance_expiry <= horizon:
            title = f"Insurance expiring: {unit.name} ({vehicle.insurance_expiry.isoformat()})"
            body = f"{unit.name}'s insurance expires on {vehicle.insurance_expiry.isoformat()}."
            for user_id in recipients:
                if _notify_if_new(db, user_id, "vehicle_insurance_expiry", title, body):
                    created += 1
        if vehicle.registration_expiry and today <= vehicle.registration_expiry <= horizon:
            title = f"Registration expiring: {unit.name} ({vehicle.registration_expiry.isoformat()})"
            body = f"{unit.name}'s registration expires on {vehicle.registration_expiry.isoformat()}."
            for user_id in recipients:
                if _notify_if_new(db, user_id, "vehicle_registration_expiry", title, body):
                    created += 1
    return created


def check_low_inventory(db: Session) -> int:
    created = 0
    recipients = _decision_maker_ids(db)
    products = db.execute(select(Product).where(Product.deleted_at.is_(None))).scalars().all()
    low_stock = [p for p in products if float(p.current_quantity) <= float(p.min_stock_level)]

    if not low_stock:
        return 0

    title = f"Low stock alert ({date.today().isoformat()})"
    names = ", ".join(p.name for p in low_stock[:8])
    body = f"{len(low_stock)} product(s) at or below minimum stock level: {names}."
    for user_id in recipients:
        if _notify_if_new(db, user_id, "low_inventory", title, body):
            created += 1
    return created


def check_high_expenses(db: Session, threshold_multiplier: float = 2.0) -> int:
    """Flags today's total expense if it's more than `threshold_multiplier`x
    the trailing-30-day daily average -- a simple anomaly signal, not a
    forecast (Section 17 'unusual financial activity')."""
    created = 0
    today = date.today()
    window_start = today - timedelta(days=30)

    trailing_total = total_expense(db, date_from=window_start, date_to=today - timedelta(days=1))
    trailing_avg = trailing_total / 30 if trailing_total else 0
    today_expense = total_expense(db, date_from=today, date_to=today)

    if trailing_avg > 0 and today_expense > trailing_avg * threshold_multiplier:
        recipients = _decision_maker_ids(db)
        title = f"Unusual expense activity ({today.isoformat()})"
        body = (
            f"Today's expenses (ETB {today_expense:,.2f}) are more than {threshold_multiplier:.0f}x "
            f"the 30-day daily average (ETB {trailing_avg:,.2f})."
        )
        for user_id in recipients:
            if _notify_if_new(db, user_id, "unusual_expense", title, body):
                created += 1
    return created


def generate_daily_summary(db: Session) -> int:
    created = 0
    today = date.today()
    recipients = _decision_maker_ids(db)
    revenue = total_revenue(db, date_from=today, date_to=today)
    expense = total_expense(db, date_from=today, date_to=today)

    title = f"Daily summary: {today.isoformat()}"
    body = f"Revenue ETB {revenue:,.2f}, Expenses ETB {expense:,.2f}, Net ETB {revenue - expense:,.2f}."
    for user_id in recipients:
        if _notify_if_new(db, user_id, "daily_summary", title, body):
            created += 1
    return created


ALL_RULES = {
    "rent_due_overdue": check_rent_due_and_overdue,
    "vehicle_maintenance": check_vehicle_maintenance_due,
    "vehicle_document_expiry": check_vehicle_document_expiry,
    "low_inventory": check_low_inventory,
    "high_expenses": check_high_expenses,
    "daily_summary": generate_daily_summary,
}


def run_all_rules(db: Session) -> tuple[int, list[str]]:
    total_created = 0
    for name, rule_fn in ALL_RULES.items():
        total_created += rule_fn(db)
    db.commit()
    return total_created, list(ALL_RULES.keys())
