import uuid
from datetime import date

from sqlalchemy import String, Numeric, Integer, ForeignKey, Date, Boolean, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.mixins import UUIDPKMixin, TimestampMixin, SoftDeleteMixin


class BusinessCategory(Base, UUIDPKMixin):
    __tablename__ = "business_categories"

    code: Mapped[str] = mapped_column(String(30), unique=True, nullable=False)  # VEHICLES, RENTAL_HOUSES, SHOP, PROJECT
    name: Mapped[str] = mapped_column(String(100), nullable=False)

    units: Mapped[list["BusinessUnit"]] = relationship(back_populates="category")


class BusinessUnit(Base, UUIDPKMixin, TimestampMixin, SoftDeleteMixin):
    """
    Polymorphic anchor row for every revenue/expense-bearing entity:
    a vehicle, a rental property, the shop, or a project.
    Revenue/expense transactions always reference business_unit_id,
    never the specific vehicle/property table directly -- this is what
    lets new vehicles/houses/shops/projects be added as pure data (Section 32).
    """
    __tablename__ = "business_units"

    category_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("business_categories.id"), nullable=False)
    unit_type: Mapped[str] = mapped_column(String(30), nullable=False)  # vehicle, property, shop, project
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    status: Mapped[str] = mapped_column(String(30), default="active")

    category: Mapped["BusinessCategory"] = relationship(back_populates="units")
    vehicle: Mapped["Vehicle | None"] = relationship(back_populates="business_unit", uselist=False)
    property: Mapped["Property | None"] = relationship(back_populates="business_unit", uselist=False)
    project: Mapped["Project | None"] = relationship(back_populates="business_unit", uselist=False)


class Vehicle(Base, UUIDPKMixin):
    __tablename__ = "vehicles"

    business_unit_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("business_units.id"), unique=True, nullable=False
    )
    plate_number: Mapped[str | None] = mapped_column(String(50))
    vehicle_type: Mapped[str | None] = mapped_column(String(50))
    manufacturer: Mapped[str | None] = mapped_column(String(50))
    model: Mapped[str | None] = mapped_column(String(50))
    year: Mapped[int | None] = mapped_column(Integer)
    purchase_date: Mapped[date | None] = mapped_column(Date)
    purchase_price: Mapped[float | None] = mapped_column(Numeric(14, 2))
    current_value: Mapped[float | None] = mapped_column(Numeric(14, 2))
    driver_name: Mapped[str | None] = mapped_column(String(150))
    mileage: Mapped[float] = mapped_column(Numeric(12, 2), default=0)
    operating_hours: Mapped[float | None] = mapped_column(Numeric(12, 2))
    status: Mapped[str] = mapped_column(String(30), default="active")
    insurance_expiry: Mapped[date | None] = mapped_column(Date)
    registration_expiry: Mapped[date | None] = mapped_column(Date)

    business_unit: Mapped["BusinessUnit"] = relationship(back_populates="vehicle")


class Property(Base, UUIDPKMixin):
    __tablename__ = "properties"

    business_unit_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("business_units.id"), unique=True, nullable=False
    )
    address: Mapped[str | None] = mapped_column(Text)
    property_type: Mapped[str | None] = mapped_column(String(50))
    rooms: Mapped[int | None] = mapped_column(Integer)
    monthly_rent: Mapped[float] = mapped_column(Numeric(14, 2), nullable=False)
    security_deposit: Mapped[float | None] = mapped_column(Numeric(14, 2))
    payment_frequency: Mapped[str | None] = mapped_column(String(20))
    status: Mapped[str] = mapped_column(String(20), default="vacant")

    business_unit: Mapped["BusinessUnit"] = relationship(back_populates="property")
    tenants: Mapped[list["Tenant"]] = relationship(back_populates="property")


class Tenant(Base, UUIDPKMixin):
    __tablename__ = "tenants"

    property_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("properties.id"))
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    phone: Mapped[str | None] = mapped_column(String(30))
    contract_start: Mapped[date | None] = mapped_column(Date)
    contract_end: Mapped[date | None] = mapped_column(Date)
    active: Mapped[bool] = mapped_column(Boolean, default=True)

    property: Mapped["Property"] = relationship(back_populates="tenants")


class Project(Base, UUIDPKMixin):
    __tablename__ = "projects"

    business_unit_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("business_units.id"), unique=True, nullable=False
    )
    initial_investment: Mapped[float] = mapped_column(Numeric(16, 2), default=0)
    additional_investment: Mapped[float] = mapped_column(Numeric(16, 2), default=0)
    status: Mapped[str] = mapped_column(String(30), default="planning")

    business_unit: Mapped["BusinessUnit"] = relationship(back_populates="project")
