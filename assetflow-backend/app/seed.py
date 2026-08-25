"""
Seeds the database with:
  - Roles + permission matrix (Section 19)
  - A super_admin user
  - Default financial accounts (Cash, Bank)
  - The exact business structure from Section 31: six vehicles, two houses,
    one Construction Materials Shop, one Gold-Mining Project -- as DATA rows,
    never hard-coded application logic.

Run with:  python -m app.seed
"""
from sqlalchemy.orm import Session

from app.core.database import SessionLocal, engine, Base
from app.core.security import hash_password
from app.models.identity import Role, Permission, User
from app.models.business import BusinessCategory, BusinessUnit, Vehicle, Property, Project
from app.models.financial import Account

VEHICLE_NAMES = [
    "EX-3952",
    "EX-4541",
    "A26401/15598",
    "A19876/35760",
    "A28405/01001",
    "Land-Cruiser",
]
HOUSE_NAMES = ["Kush-House", "Kosober-House"]

DOMAIN_RESOURCES = ["vehicles", "properties", "shop", "projects"]

ROLE_PERMISSIONS = {
    "super_admin": None,  # bypassed entirely in dependencies.require_permission
    "manager": [
        ("revenue", "create"), ("revenue", "read"), ("revenue", "update"), ("revenue", "delete"),
        ("expense", "create"), ("expense", "read"), ("expense", "update"), ("expense", "delete"),
        ("accounts", "read"), ("accounts", "update"),
        ("reports", "read"),
        *[(r, a) for r in DOMAIN_RESOURCES for a in ("create", "read", "update")],
    ],
    "accountant": [
        ("revenue", "create"), ("revenue", "read"), ("revenue", "update"),
        ("expense", "create"), ("expense", "read"), ("expense", "update"),
        ("accounts", "read"),
        ("reports", "read"),
        *[(r, "read") for r in DOMAIN_RESOURCES],
    ],
    "staff": [
        ("revenue", "create"), ("revenue", "read"),
        ("expense", "create"), ("expense", "read"),
        *[(r, "create") for r in DOMAIN_RESOURCES],
        *[(r, "read") for r in DOMAIN_RESOURCES],
    ],
    "viewer": [
        ("revenue", "read"),
        ("expense", "read"),
        ("reports", "read"),
        *[(r, "read") for r in DOMAIN_RESOURCES],
    ],
}


def seed(db: Session) -> None:
    # --- Roles & permissions ---
    roles: dict[str, Role] = {}
    for role_name in ROLE_PERMISSIONS:
        role = db.query(Role).filter(Role.name == role_name).one_or_none()
        if role is None:
            role = Role(name=role_name)
            db.add(role)
            db.flush()
        roles[role_name] = role

    for role_name, perms in ROLE_PERMISSIONS.items():
        if not perms:
            continue
        for resource, action in perms:
            exists = (
                db.query(Permission)
                .filter(Permission.role_id == roles[role_name].id, Permission.resource == resource, Permission.action == action)
                .one_or_none()
            )
            if exists is None:
                db.add(Permission(role_id=roles[role_name].id, resource=resource, action=action))

        # --- Admin user ---
    admin = db.query(User).filter(User.email == "admin@assetflow.app").one_or_none()
    if admin is None:
        admin = User(
            full_name="Admin User",
            email="admin@assetflow.app",
            password_hash=hash_password("ChangeMe123!"),
            role_id=roles["super_admin"].id,
        )
        db.add(admin)
    elif admin.full_name == "System Administrator":
        # One-time self-correction: earlier seed runs created the admin with
        # this placeholder name, which showed up in the app as "Hello, System"
        # (the dashboard greets by first name). Since seed() only *creates*
        # missing rows and never overwrites existing ones, changing the
        # default above wouldn't have fixed an already-seeded database on its
        # own -- this narrow check does, on the next deploy, without touching
        # anything an admin may have deliberately renamed to something else.
        admin.full_name = "Admin User"
        db.add(admin)

    # --- Default accounts ---
    if db.query(Account).count() == 0:
        db.add(Account(name="Main Cash", account_type="cash", currency="ETB"))
        db.add(Account(name="Main Bank Account", account_type="bank", currency="ETB"))

    # --- Business categories ---
    categories = {}
    for code, name in [
        ("VEHICLES", "Vehicles"),
        ("RENTAL_HOUSES", "Houses"),
        ("SHOP", "Shops"),
        ("PROJECT", "Projects"),
    ]:
        cat = db.query(BusinessCategory).filter(BusinessCategory.code == code).one_or_none()
        if cat is None:
            cat = BusinessCategory(code=code, name=name)
            db.add(cat)
            db.flush()
        categories[code] = cat

    # --- Vehicles (Section 31) ---
    for name in VEHICLE_NAMES:
        unit = db.query(BusinessUnit).filter(BusinessUnit.name == name, BusinessUnit.unit_type == "vehicle").one_or_none()
        if unit is None:
            unit = BusinessUnit(category_id=categories["VEHICLES"].id, unit_type="vehicle", name=name)
            db.add(unit)
            db.flush()
            db.add(Vehicle(business_unit_id=unit.id, status="active"))

    # --- Rental houses (Section 31) ---
    for name in HOUSE_NAMES:
        unit = db.query(BusinessUnit).filter(BusinessUnit.name == name, BusinessUnit.unit_type == "property").one_or_none()
        if unit is None:
            unit = BusinessUnit(category_id=categories["RENTAL_HOUSES"].id, unit_type="property", name=name)
            db.add(unit)
            db.flush()
            # monthly_rent left at a placeholder; must be set via the Property Management screen (Section 5).
            db.add(Property(business_unit_id=unit.id, monthly_rent=0, status="vacant"))

    # --- Construction Materials Shop (single unit, Section 6/31) ---
    shop_unit = db.query(BusinessUnit).filter(BusinessUnit.unit_type == "shop").one_or_none()
    if shop_unit is None:
        shop_unit = BusinessUnit(category_id=categories["SHOP"].id, unit_type="shop", name="Shops")
        db.add(shop_unit)
        db.flush()

    # --- Gold-Mining Project (Section 31) ---
    project_unit = db.query(BusinessUnit).filter(BusinessUnit.unit_type == "project").one_or_none()
    if project_unit is None:
        project_unit = BusinessUnit(category_id=categories["PROJECT"].id, unit_type="project", name="Projects")
        db.add(project_unit)
        db.flush()
        db.add(Project(business_unit_id=project_unit.id, status="planning"))

    db.commit()
    print("Seed complete.")
    print("Admin login: admin@assetflow.app / ChangeMe123!  (change immediately in production)")


if __name__ == "__main__":
    Base.metadata.create_all(bind=engine)  # convenience for local dev; use Alembic in real deployments
    with SessionLocal() as session:
        seed(session)
