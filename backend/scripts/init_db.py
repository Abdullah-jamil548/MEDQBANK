"""Create users/books schemas and tables in the master_schema database."""

from app.db import init_schemas_and_tables


if __name__ == "__main__":
    init_schemas_and_tables()
    print("Schemas users/books and tables created successfully.")
