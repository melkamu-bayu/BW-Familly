"""initial schema

Revision ID: 0001
Revises:
Create Date: 2026-08-13

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"')

    op.create_table(
        "roles",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("name", sa.String(50), nullable=False, unique=True),
        sa.Column("description", sa.Text(), nullable=True),
    )

    op.create_table(
        "permissions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("role_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("roles.id")),
        sa.Column("resource", sa.String(100), nullable=False),
        sa.Column("action", sa.String(20), nullable=False),
        sa.UniqueConstraint("role_id", "resource", "action", name="uq_role_resource_action"),
    )

    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("full_name", sa.String(150), nullable=False),
        sa.Column("email", sa.String(150), nullable=False, unique=True),
        sa.Column("phone", sa.String(30)),
        sa.Column("password_hash", sa.Text(), nullable=False),
        sa.Column("role_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("roles.id"), nullable=False),
        sa.Column("biometric_enabled", sa.Boolean(), server_default=sa.text("false")),
        sa.Column("pin_hash", sa.Text()),
        sa.Column("active", sa.Boolean(), server_default=sa.text("true")),
        sa.Column("last_login_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("deleted_at", sa.DateTime(timezone=True)),
    )
    op.create_index("ix_users_email", "users", ["email"])

    op.create_table(
        "refresh_tokens",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("jti", sa.String(64), nullable=False, unique=True),
        sa.Column("revoked", sa.Boolean(), server_default=sa.text("false")),
        sa.Column("replaced_by_jti", sa.String(64)),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "business_categories",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("code", sa.String(30), nullable=False, unique=True),
        sa.Column("name", sa.String(100), nullable=False),
    )

    op.create_table(
        "business_units",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("category_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("business_categories.id"), nullable=False),
        sa.Column("unit_type", sa.String(30), nullable=False),
        sa.Column("name", sa.String(150), nullable=False),
        sa.Column("status", sa.String(30), server_default="active"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("deleted_at", sa.DateTime(timezone=True)),
    )

    op.create_table(
        "vehicles",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("business_unit_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("business_units.id"), nullable=False, unique=True),
        sa.Column("plate_number", sa.String(50)),
        sa.Column("vehicle_type", sa.String(50)),
        sa.Column("manufacturer", sa.String(50)),
        sa.Column("model", sa.String(50)),
        sa.Column("year", sa.Integer()),
        sa.Column("purchase_date", sa.Date()),
        sa.Column("purchase_price", sa.Numeric(14, 2)),
        sa.Column("current_value", sa.Numeric(14, 2)),
        sa.Column("driver_name", sa.String(150)),
        sa.Column("mileage", sa.Numeric(12, 2), server_default="0"),
        sa.Column("operating_hours", sa.Numeric(12, 2)),
        sa.Column("status", sa.String(30), server_default="active"),
        sa.Column("insurance_expiry", sa.Date()),
        sa.Column("registration_expiry", sa.Date()),
    )

    op.create_table(
        "properties",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("business_unit_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("business_units.id"), nullable=False, unique=True),
        sa.Column("address", sa.Text()),
        sa.Column("property_type", sa.String(50)),
        sa.Column("rooms", sa.Integer()),
        sa.Column("monthly_rent", sa.Numeric(14, 2), nullable=False),
        sa.Column("security_deposit", sa.Numeric(14, 2)),
        sa.Column("payment_frequency", sa.String(20)),
        sa.Column("status", sa.String(20), server_default="vacant"),
    )

    op.create_table(
        "tenants",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("property_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("properties.id")),
        sa.Column("name", sa.String(150), nullable=False),
        sa.Column("phone", sa.String(30)),
        sa.Column("contract_start", sa.Date()),
        sa.Column("contract_end", sa.Date()),
        sa.Column("active", sa.Boolean(), server_default=sa.text("true")),
    )

    op.create_table(
        "projects",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("business_unit_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("business_units.id"), nullable=False, unique=True),
        sa.Column("initial_investment", sa.Numeric(16, 2), server_default="0"),
        sa.Column("additional_investment", sa.Numeric(16, 2), server_default="0"),
        sa.Column("status", sa.String(30), server_default="planning"),
    )

    op.create_table(
        "product_categories",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("name", sa.String(100), nullable=False, unique=True),
    )

    op.create_table(
        "products",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("business_unit_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("business_units.id"), nullable=False),
        sa.Column("name", sa.String(150), nullable=False),
        sa.Column("sku", sa.String(60), unique=True),
        sa.Column("barcode", sa.String(60)),
        sa.Column("category_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("product_categories.id")),
        sa.Column("unit", sa.String(20), nullable=False),
        sa.Column("purchase_price", sa.Numeric(14, 2)),
        sa.Column("selling_price", sa.Numeric(14, 2)),
        sa.Column("current_quantity", sa.Numeric(14, 3), server_default="0"),
        sa.Column("min_stock_level", sa.Numeric(14, 3), server_default="0"),
        sa.Column("warehouse_location", sa.String(100)),
        sa.Column("deleted_at", sa.DateTime(timezone=True)),
    )

    op.create_table(
        "suppliers",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("name", sa.String(150), nullable=False),
        sa.Column("phone", sa.String(30)),
        sa.Column("email", sa.String(150)),
        sa.Column("address", sa.Text()),
        sa.Column("outstanding_payable", sa.Numeric(14, 2), server_default="0"),
    )

    op.create_table(
        "customers",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("name", sa.String(150), nullable=False),
        sa.Column("phone", sa.String(30)),
        sa.Column("email", sa.String(150)),
        sa.Column("address", sa.Text()),
        sa.Column("credit_limit", sa.Numeric(14, 2), server_default="0"),
        sa.Column("outstanding_balance", sa.Numeric(14, 2), server_default="0"),
    )

    op.create_table(
        "purchases",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("invoice_number", sa.String(60), nullable=False, unique=True),
        sa.Column("supplier_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("suppliers.id")),
        sa.Column("business_unit_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("business_units.id")),
        sa.Column("total_cost", sa.Numeric(16, 2), nullable=False),
        sa.Column("payment_status", sa.String(20), server_default="pending"),
        sa.Column("purchase_date", sa.Date(), nullable=False),
        sa.Column("created_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "purchase_items",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("purchase_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("purchases.id", ondelete="CASCADE")),
        sa.Column("product_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("products.id"), nullable=False),
        sa.Column("quantity", sa.Numeric(14, 3), nullable=False),
        sa.Column("unit_price", sa.Numeric(14, 2), nullable=False),
        sa.Column("line_total", sa.Numeric(16, 2), nullable=False),
    )

    op.create_table(
        "sales",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("invoice_number", sa.String(60), nullable=False, unique=True),
        sa.Column("customer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("customers.id")),
        sa.Column("business_unit_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("business_units.id")),
        sa.Column("total_amount", sa.Numeric(16, 2), nullable=False),
        sa.Column("discount", sa.Numeric(14, 2), server_default="0"),
        sa.Column("payment_method", sa.String(30)),
        sa.Column("payment_status", sa.String(20), server_default="paid"),
        sa.Column("sale_date", sa.Date(), nullable=False),
        sa.Column("created_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "sale_items",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("sale_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("sales.id", ondelete="CASCADE")),
        sa.Column("product_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("products.id"), nullable=False),
        sa.Column("quantity", sa.Numeric(14, 3), nullable=False),
        sa.Column("unit_price", sa.Numeric(14, 2), nullable=False),
        sa.Column("line_total", sa.Numeric(16, 2), nullable=False),
    )

    op.create_table(
        "inventory_transactions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("product_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("products.id"), nullable=False),
        sa.Column("txn_type", sa.String(20), nullable=False),
        sa.Column("reference_id", postgresql.UUID(as_uuid=True)),
        sa.Column("quantity_change", sa.Numeric(14, 3), nullable=False),
        sa.Column("resulting_quantity", sa.Numeric(14, 3), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_inventory_product", "inventory_transactions", ["product_id"])

    op.create_table(
        "accounts",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("account_type", sa.String(30), nullable=False),
        sa.Column("account_number", sa.String(60)),
        sa.Column("opening_balance", sa.Numeric(16, 2), server_default="0"),
        sa.Column("current_balance", sa.Numeric(16, 2), server_default="0"),
        sa.Column("currency", sa.String(10), server_default="ETB"),
        sa.Column("status", sa.String(20), server_default="active"),
    )

    op.create_table(
        "revenue_transactions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("transaction_code", sa.String(30), nullable=False, unique=True),
        sa.Column("business_unit_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("business_units.id"), nullable=False),
        sa.Column("account_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("accounts.id"), nullable=False),
        sa.Column("customer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("customers.id")),
        sa.Column("category", sa.String(60), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("amount", sa.Numeric(16, 2), nullable=False),
        sa.Column("currency", sa.String(10), server_default="ETB"),
        sa.Column("payment_method", sa.String(30)),
        sa.Column("payment_status", sa.String(20), server_default="received"),
        sa.Column("reference_number", sa.String(60)),
        sa.Column("txn_date", sa.Date(), nullable=False),
        sa.Column("idempotency_key", postgresql.UUID(as_uuid=True), unique=True),
        sa.Column("created_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("deleted_at", sa.DateTime(timezone=True)),
        sa.CheckConstraint("amount >= 0", name="ck_revenue_amount_nonneg"),
    )
    op.create_index("idx_revenue_unit_date", "revenue_transactions", ["business_unit_id", "txn_date"])

    op.create_table(
        "expense_transactions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("transaction_code", sa.String(30), nullable=False, unique=True),
        sa.Column("business_unit_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("business_units.id"), nullable=False),
        sa.Column("account_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("accounts.id"), nullable=False),
        sa.Column("supplier_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("suppliers.id")),
        sa.Column("category", sa.String(60), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("amount", sa.Numeric(16, 2), nullable=False),
        sa.Column("currency", sa.String(10), server_default="ETB"),
        sa.Column("payment_method", sa.String(30)),
        sa.Column("payment_status", sa.String(20), server_default="paid"),
        sa.Column("invoice_number", sa.String(60)),
        sa.Column("txn_date", sa.Date(), nullable=False),
        sa.Column("idempotency_key", postgresql.UUID(as_uuid=True), unique=True),
        sa.Column("created_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("deleted_at", sa.DateTime(timezone=True)),
        sa.CheckConstraint("amount >= 0", name="ck_expense_amount_nonneg"),
    )
    op.create_index("idx_expense_unit_date", "expense_transactions", ["business_unit_id", "txn_date"])

    op.create_table(
        "payments",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("transaction_code", sa.String(30), nullable=False, unique=True),
        sa.Column("account_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("accounts.id"), nullable=False),
        sa.Column("direction", sa.String(10), nullable=False),
        sa.Column("related_type", sa.String(30)),
        sa.Column("related_id", postgresql.UUID(as_uuid=True)),
        sa.Column("amount", sa.Numeric(16, 2), nullable=False),
        sa.Column("payment_date", sa.Date(), nullable=False),
        sa.Column("created_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "account_transfers",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("from_account_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("accounts.id"), nullable=False),
        sa.Column("to_account_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("accounts.id"), nullable=False),
        sa.Column("amount", sa.Numeric(16, 2), nullable=False),
        sa.Column("transfer_date", sa.Date(), nullable=False),
        sa.Column("created_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "rental_transactions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("property_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("properties.id"), nullable=False),
        sa.Column("tenant_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tenants.id")),
        sa.Column("period_month", sa.Date(), nullable=False),
        sa.Column("amount_due", sa.Numeric(14, 2), nullable=False),
        sa.Column("amount_paid", sa.Numeric(14, 2), server_default="0"),
        sa.Column("status", sa.String(20), server_default="outstanding"),
    )
    op.create_index("idx_rental_property_period", "rental_transactions", ["property_id", "period_month"])

    op.create_table(
        "maintenance_records",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("business_unit_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("business_units.id"), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("cost", sa.Numeric(14, 2)),
        sa.Column("performed_at", sa.Date()),
        sa.Column("next_due", sa.Date()),
    )

    op.create_table(
        "project_transactions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("project_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("projects.id"), nullable=False),
        sa.Column("txn_type", sa.String(30), nullable=False),
        sa.Column("category", sa.String(60)),
        sa.Column("amount", sa.Numeric(16, 2), nullable=False),
        sa.Column("txn_date", sa.Date(), nullable=False),
        sa.Column("created_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id")),
    )

    op.create_table(
        "attachments",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("owner_type", sa.String(40), nullable=False),
        sa.Column("owner_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("file_url", sa.Text(), nullable=False),
        sa.Column("uploaded_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id")),
        sa.Column("uploaded_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "notifications",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id")),
        sa.Column("type", sa.String(50), nullable=False),
        sa.Column("title", sa.String(200)),
        sa.Column("body", sa.Text()),
        sa.Column("is_read", sa.Boolean(), server_default=sa.text("false")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "audit_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("uuid_generate_v4()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id")),
        sa.Column("entity_type", sa.String(50), nullable=False),
        sa.Column("entity_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("action", sa.String(20), nullable=False),
        sa.Column("previous_value", postgresql.JSONB()),
        sa.Column("new_value", postgresql.JSONB()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_audit_entity", "audit_logs", ["entity_type", "entity_id"])


def downgrade() -> None:
    op.drop_table("audit_logs")
    op.drop_table("notifications")
    op.drop_table("attachments")
    op.drop_table("project_transactions")
    op.drop_table("maintenance_records")
    op.drop_table("rental_transactions")
    op.drop_table("account_transfers")
    op.drop_table("payments")
    op.drop_table("expense_transactions")
    op.drop_table("revenue_transactions")
    op.drop_table("accounts")
    op.drop_table("inventory_transactions")
    op.drop_table("sale_items")
    op.drop_table("sales")
    op.drop_table("purchase_items")
    op.drop_table("purchases")
    op.drop_table("customers")
    op.drop_table("suppliers")
    op.drop_table("products")
    op.drop_table("product_categories")
    op.drop_table("projects")
    op.drop_table("tenants")
    op.drop_table("properties")
    op.drop_table("vehicles")
    op.drop_table("business_units")
    op.drop_table("business_categories")
    op.drop_table("refresh_tokens")
    op.drop_table("users")
    op.drop_table("permissions")
    op.drop_table("roles")
