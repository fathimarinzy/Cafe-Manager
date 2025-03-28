from flask import Blueprint, jsonify,request
from models import MenuItem,db
from auth import token_required

menu_bp = Blueprint('menu', __name__)

# Add a new category
@menu_bp.route('/api/menu/categories', methods=['POST'])
@token_required
def add_category(current_user):
    data = request.json
    if not data or 'name' not in data:
        return jsonify({'message': 'No category name provided'}), 400
    
    # Check if category already exists
    existing_categories = db.session.query(MenuItem.category).distinct().all()
    existing_categories = [c[0] for c in existing_categories]
    
    if data['name'] in existing_categories:
        return jsonify({'message': 'Category already exists'}), 400
    
    # Since categories are just strings in MenuItem objects,
    # we don't actually need to add anything to the database here
    
    return jsonify({'message': 'Category added successfully', 'name': data['name']}), 201




# Get all menu items
@menu_bp.route('/api/menu', methods=['GET'])
@token_required
def get_menu(current_user):
    menu_items = MenuItem.query.all()
    result = []
    for item in menu_items:
        result.append({
            'id': str(item.id),
            'name': item.name,
            'price': item.price,
            'image': item.image,
            'category': item.category,
            'available': item.available
        })
    return jsonify(result), 200

# Get menu items by category
@menu_bp.route('/api/menu/categories', methods=['GET'])
@token_required
def get_categories(current_user):
    from models import db
    categories = db.session.query(MenuItem.category).distinct().all()
    result = [category[0] for category in categories]
    return jsonify(result), 200

# Add a new menu item
@menu_bp.route('/api/menu', methods=['POST'])
@token_required
def add_menu_item(current_user):
    data = request.json
    if not data:
        return jsonify({'message': 'No input data provided'}), 400

    required_fields = ['name', 'price', 'category']
    if not all(field in data for field in required_fields):
        return jsonify({'message': 'Missing required fields'}), 400

    new_item = MenuItem(
        name=data['name'],
        price=data['price'],
        image=data.get('image', ''),
        category=data['category'],
        available=data.get('available', True)
    )

    db.session.add(new_item)
    db.session.commit()

    return jsonify({
        'id': str(new_item.id),
        'name': new_item.name,
        'price': new_item.price,
        'image': new_item.image,
        'category': new_item.category,
        'available': new_item.available
    }), 201


# Update a menu item
@menu_bp.route('/api/menu/<item_id>', methods=['PUT'])
@token_required
def update_menu_item(current_user, item_id):
    data = request.json
    if not data:
        return jsonify({'message': 'No input data provided'}), 400

    item = MenuItem.query.get(item_id)
    if not item:
        return jsonify({'message': 'Menu item not found'}), 404

    if 'name' in data:
        item.name = data['name']
    if 'price' in data:
        item.price = data['price']
    if 'image' in data:
        item.image = data['image']
    if 'category' in data:
        item.category = data['category']
    if 'available' in data:
        item.available = data['available']

    db.session.commit()

    return jsonify({
        'id': str(item.id),
        'name': item.name,
        'price': item.price,
        'image': item.image,
        'category': item.category,
        'available': item.available
    }), 200

# Delete a menu item
@menu_bp.route('/api/menu/<item_id>', methods=['DELETE'])
@token_required
def delete_menu_item(current_user, item_id):
    item = MenuItem.query.get(item_id)
    if not item:
        return jsonify({'message': 'Menu item not found'}), 404

    db.session.delete(item)
    db.session.commit()

    return jsonify({'message': 'Menu item deleted successfully'}), 200

# Get menu items by category
@menu_bp.route('/api/menu/category/<category>', methods=['GET'])
@token_required
def get_menu_by_category(current_user, category):
    menu_items = MenuItem.query.filter_by(category=category).all()
    result = []
    for item in menu_items:
        result.append({
            'id': str(item.id),
            'name': item.name,
            'price': item.price,
            'image': item.image,
            'category': item.category,
            'available': item.available
        })
    return jsonify(result), 200