import logging
import structlog
from fastmcp import FastMCP
import psycopg2
import redis
import os

logging.basicConfig(format="%(message)s", level=logging.INFO)
structlog.configure(
    processors=[
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
)

mcp = FastMCP()

# Database and Redis connections
db_conn = psycopg2.connect(os.getenv("DATABASE_URL"))
redis_client = redis.Redis.from_url(os.getenv("REDIS_URL"))


@mcp.route("/lookup_customer")
async def lookup_customer(customer_id=None, email=None):
    logger = structlog.get_logger()
    logger.info("Looking up customer", customer_id=customer_id, email=email)
    with db_conn.cursor() as cur:
        if customer_id:
            cur.execute(
                "SELECT id, name, email FROM customers WHERE id = %s",
                (customer_id,)
            )
        elif email:
            cur.execute(
                "SELECT id, name, email FROM customers WHERE email = %s",
                (email,)
            )
        else:
            return {"error": "Customer ID or email required"}
        result = cur.fetchone()
        if result:
            return {"id": result[0], "name": result[1], "email": result[2]}
        return {"error": "Customer not found"}


@mcp.route("/health")
async def health_check():
    try:
        with db_conn.cursor() as cur:
            cur.execute("SELECT 1")
        redis_client.ping()
        return {"status": "OK"}
    except Exception as e:
        return {"status": "ERROR", "error": str(e)}


if __name__ == "__main__":
    mcp.run(host="0.0.0.0", port=8000)
