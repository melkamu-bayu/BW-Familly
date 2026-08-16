"""
Import every model module here so that Base.metadata sees all tables.
Required for Alembic autogenerate and for Base.metadata.create_all() in dev/tests.
"""
from app.models.identity import Role, Permission, User, RefreshToken  # noqa: F401
from app.models.business import (  # noqa: F401
    BusinessCategory,
    BusinessUnit,
    Vehicle,
    Property,
    Tenant,
    Project,
)
from app.models.shop import (  # noqa: F401
    ProductCategory,
    Product,
    Supplier,
    Customer,
    Purchase,
    PurchaseItem,
    Sale,
    SaleItem,
    InventoryTransaction,
)
from app.models.financial import (  # noqa: F401
    Account,
    RevenueTransaction,
    ExpenseTransaction,
    Payment,
    AccountTransfer,
    RentalTransaction,
    MaintenanceRecord,
    ProjectTransaction,
)
from app.models.support import Attachment, Notification, AuditLog  # noqa: F401
