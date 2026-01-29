from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application configuration settings."""
    
    # Database
    database_url: str = "postgresql+asyncpg://xero_user:xero_password@postgres:5432/xero_automation"
    
    # Encryption
    encryption_key: str = "your-32-byte-fernet-key-here-change-me"
    
    # Playwright
    playwright_timeout: int = 30000  # milliseconds
    headless: bool = True  # Set to False for manual auth setup
    
    # Directories
    download_dir: str = "/app/downloads"
    screenshot_dir: str = "/app/screenshots"
    session_dir: str = "/app/sessions"
    
    # Logging
    log_level: str = "INFO"
    
    # Optional: n8n webhook for notifications
    n8n_webhook_url: str | None = None
    
    # Xero credentials for automated login
    xero_email: str | None = None
    xero_password: str | None = None
    
    # Xero security question answers (for MFA bypass)
    # Question 1: "As a child, what did you want to be when you grew up?"
    xero_security_answer_1: str | None = None
    # Question 2: "What is your most disliked holiday?"
    xero_security_answer_2: str | None = None
    # Question 3: "What is your dream job?"
    xero_security_answer_3: str | None = None
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
