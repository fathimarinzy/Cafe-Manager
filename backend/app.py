from flask import Flask
from flask_cors import CORS
import os
import secrets
from config import DATABASE_URI, DEBUG, PORT, HOST
from models import db
from database import init_db
from routes.auth import auth_bp
from routes.menu import menu_bp
from routes.orders import orders_bp
from routes.persons import persons_bp 

def create_app():
    """Application factory function"""
    # Initialize Flask app
    app = Flask(__name__)

    CORS(app)  # Enable CORS for all routes
    # print(secrets.token_hex(32))
    
    # Configure app
    app.config['SECRET_KEY'] = 'your-secret-key-change-in-production'
    app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_URI
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    
    # Initialize extensions
    db.init_app(app)
    
    # Register blueprints
    app.register_blueprint(auth_bp)
    app.register_blueprint(menu_bp)
    app.register_blueprint(orders_bp)
    app.register_blueprint(persons_bp) 
    # Initialize database
    init_db(app)
    
    return app

if __name__ == '__main__':
    app = create_app()
    app.run(host='0.0.0.0', port=5000, debug=True)
