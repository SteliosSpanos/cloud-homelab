import os
import json
import boto3
from fastapi import FastAPI, Request, Depends, Form
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import Column, Integer, String, create_engine, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic_settings import BaseSettings

# --- CONFIGURATION ---

class Settings(BaseSettings):
    region_name: str = os.getenv("AWS_REGION", "us-east-1")
    db_secret_id: str = os.getenv("DB_SECRET_ID", "")
    db_host: str = os.getenv("DB_HOST", "localhost")
    db_port: str = os.getenv("DB_PORT", "5432")
    db_name: str = os.getenv("DB_NAME", "homelab")

settings = Settings()

# --- AWS SECRETS MANAGER ---

def get_db_credentials():
    """Fetches DB credentials from AWS Secrets Manager."""
    if not settings.db_secret_id:
        print("DB_SECRET_ID not set, using environment variables")
        return {
            "username": os.getenv("DB_USER", "postgres"),
            "password": os.getenv("DB_PASSWORD", "password")
        }

    client = boto3.client('secretsmanager', region_name=settings.region_name)
    try:
        response = client.get_secret_value(SecretId=settings.db_secret_id)
        if 'SecretString' in response:
            return json.loads(response['SecretString'])
    except Exception as e:
        print(f"Error fetching secret: {e}")
    
    return {
        "username": os.getenv("DB_USER", "postgres"),
        "password": os.getenv("DB_PASSWORD", "password")
    }

# --- DATABASE SETUP ---

creds = get_db_credentials()
# Force SSL since RDS is configured with rds.force_ssl=1
DATABASE_URL = f"postgresql://{creds['username']}:{creds['password']}@{settings.db_host}:{settings.db_port}/{settings.db_name}?sslmode=require"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class Item(Base):
    __tablename__ = "items"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    description = Column(String)

# Create tables
try:
    Base.metadata.create_all(bind=engine)
except Exception as e:
    print(f"CRITICAL: Failed to create database tables: {e}")

# --- FASTAPI APP ---

app = FastAPI(title="Homelab Web App")
templates = Jinja2Templates(directory="templates")

# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/", response_class=HTMLResponse)
async def read_items(request: Request, db: Session = Depends(get_db)):
    try:
        items = db.query(Item).all()
        return templates.TemplateResponse("index.html", {"request": request, "items": items})
    except Exception as e:
        return HTMLResponse(content=f"Error connecting to database: {str(e)}", status_code=500)

@app.post("/add")
async def add_item(name: str = Form(...), description: str = Form(...), db: Session = Depends(get_db)):
    new_item = Item(name=name, description=description)
    db.add(new_item)
    db.commit()
    return RedirectResponse(url="/", status_code=303)

@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    try:
        # Simple query to check DB health
        db.execute(text("SELECT 1"))
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        return {"status": "unhealthy", "database": str(e)}
