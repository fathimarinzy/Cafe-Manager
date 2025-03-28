from werkzeug.security import generate_password_hash
from models import db, User, MenuItem

def init_db(app):
    """Initialize the database, create tables, and seed initial data if needed"""
    with app.app_context():
        try:
            db.create_all()
            print("Database tables created successfully")
            
            # Check if we need to seed the database with initial data
            if User.query.count() == 0:
                # Create default users
                print("Seeding default users...")
                db.session.add(User(username='admin', password=generate_password_hash('admin123')))
                db.session.add(User(username='user', password=generate_password_hash('user123')))
                db.session.commit()
            
            # # Check if we need to seed menu items
            # if MenuItem.query.count() == 0:
            #     print("Seeding default menu items...")
            #     # Create default menu items
            #     default_menu = [
            #         {
            #             "name": "Cappuccino",
            #             "price": 4.50,
            #             "image": "https://images.unsplash.com/photo-1534778101976-62847782c213?q=80&w=2070&auto=format&fit=crop",
            #             "category": "coffee",
            #             "available": True
            #         },
            #         {
            #             "name": "Latte",
            #             "price": 4.00,
            #             "image": "https://images.unsplash.com/photo-1593443320739-77f74939d0da?q=80&w=1854&auto=format&fit=crop",
            #             "category": "coffee",
            #             "available": True
            #         },
            #         {
            #             "name": "Espresso",
            #             "price": 3.00,
            #             "image": "https://images.unsplash.com/photo-1579992357154-faf4bde95b3d?q=80&w=1887&auto=format&fit=crop",
            #             "category": "coffee",
            #             "available": True
            #         },
            #         {
            #             "name": "Croissant",
            #             "price": 3.50,
            #             "image": "https://images.unsplash.com/photo-1555507036-ab1f4038808a?q=80&w=2026&auto=format&fit=crop",
            #             "category": "pastry",
            #             "available": True
            #         },
            #         {
            #             "name": "Chocolate Cake",
            #             "price": 5.00,
            #             "image": "https://images.unsplash.com/photo-1578985545062-69928b1d9587?q=80&w=1989&auto=format&fit=crop",
            #             "category": "pastry",
            #             "available": True
            #         },
            #         {
            #             "name": "Green Tea",
            #             "price": 3.50,
            #             "image": "https://images.unsplash.com/photo-1627435601361-ec25f5b1d0e5?q=80&w=2070&auto=format&fit=crop",
            #             "category": "tea",
            #             "available": True
            #         }
            #     ]
                
            #     for item in default_menu:
            #         db.session.add(MenuItem(**item))
                
            #     db.session.commit()
        except Exception as e:
            print(f"Error initializing database: {e}")
