from fastapi import APIRouter

from app.api.v1 import (
    auth,
    revenue,
    expenses,
    accounts,
    dashboard,
    vehicles,
    properties,
    shop,
    projects,
    reports,
    analytics,
    sync,
    notifications,
    backup,
)

api_router = APIRouter()

api_router.include_router(auth.router)
api_router.include_router(revenue.router)
api_router.include_router(expenses.router)
api_router.include_router(accounts.router)
api_router.include_router(dashboard.router)
api_router.include_router(vehicles.router)
api_router.include_router(properties.router)
api_router.include_router(shop.router)
api_router.include_router(projects.router)
api_router.include_router(reports.router)
api_router.include_router(analytics.router)
api_router.include_router(sync.router)
api_router.include_router(notifications.router)
api_router.include_router(backup.router)
