import os
import urllib.parse
from dotenv import load_dotenv
load_dotenv()
# Secret key for JWT tokens
SECRET_KEY = os.getenv("SECRET_KEY", "default-secret-key")

# Configure MySQL connection
MYSQL_USER = os.environ.get('MYSQL_USER', 'root')
MYSQL_PASSWORD = urllib.parse.quote_plus(os.getenv('MYSQL_PASSWORD', 'Fathimarinzy@02'))  # Encode special characters
MYSQL_HOST = os.environ.get('MYSQL_HOST', '127.0.0.1')
MYSQL_PORT = os.environ.get('MYSQL_PORT', '3306') 
MYSQL_DB = os.environ.get('MYSQL_DB', 'cafedb')

# Print connection info for debugging
print(f"Connecting to MySQL: {MYSQL_USER}@{MYSQL_HOST}:{MYSQL_PORT}/{MYSQL_DB}")

# Database URI
DATABASE_URI = f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:{MYSQL_PORT}/{MYSQL_DB}"

# Flask config
DEBUG = True
PORT = 5000
HOST = '0.0.0.0'
