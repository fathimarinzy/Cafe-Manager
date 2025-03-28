from flask import Blueprint, request, jsonify
from datetime import datetime
from models import db, Order, OrderItem
from auth import token_required

orders_bp = Blueprint('orders', __name__)

@orders_bp.route('/api/orders', methods=['POST'])
@token_required
def create_order(current_user):
    data = request.json
    if not data:
        return jsonify({'message': 'No input data provided'}), 400
    
    # Validate order data
    required_fields = ['serviceType', 'items', 'total']
    if not all(field in data for field in required_fields):
        return jsonify({'message': 'Missing required fields'}), 400
    
    # Create new order
    new_order = Order(
        user_id=current_user.id,
        service_type=data['serviceType'],
        subtotal=data.get('subtotal', 0),
        tax=data.get('tax', 0),
        discount=data.get('discount', 0),
        total=data['total'],
        status='pending',
        created_at=datetime.now()
    )
    
    db.session.add(new_order)
    db.session.flush()  # Flush to get the order ID
    
    # Add order items
    for item_data in data['items']:
        order_item = OrderItem(
            order_id=new_order.id,
            menu_item_id=int(item_data['id']),
            quantity=item_data.get('quantity', 1),
            price=item_data['price']
        )
        db.session.add(order_item)
    
    db.session.commit()
    
    # Format response
    response = {
        'id': str(new_order.id),
        'userId': str(new_order.user_id),
        'serviceType': new_order.service_type,
        'items': data['items'],  # Use the original items for consistency
        'subtotal': new_order.subtotal,
        'tax': new_order.tax,
        'discount': new_order.discount,
        'total': new_order.total,
        'status': new_order.status,
        'createdAt': new_order.created_at.isoformat()
    }
    
    return jsonify(response), 201

@orders_bp.route('/api/orders', methods=['GET'])
@token_required
def get_orders(current_user):
    orders = Order.query.filter_by(user_id=current_user.id).all()
    result = []
    
    for order in orders:
        order_items = []
        for item in order.items:
            menu_item = item.menu_item
            order_items.append({
                'id': str(menu_item.id),
                'name': menu_item.name,
                'price': item.price,
                'quantity': item.quantity
            })
            
        result.append({
            'id': str(order.id),
            'userId': str(order.user_id),
            'serviceType': order.service_type,
            'items': order_items,
            'subtotal': order.subtotal,
            'tax': order.tax,
            'discount': order.discount,
            'total': order.total,
            'status': order.status,
            'createdAt': order.created_at.isoformat()
        })
    
    return jsonify(result), 200

@orders_bp.route('/api/orders/<order_id>', methods=['GET'])
@token_required
def get_order(current_user, order_id):
    order = Order.query.get(order_id)
    
    if not order:
        return jsonify({'message': 'Order not found'}), 404
    
    # Check if the order belongs to the current user
    if order.user_id != current_user.id:
        return jsonify({'message': 'Unauthorized access'}), 403
    
    order_items = []
    for item in order.items:
        menu_item = item.menu_item
        order_items.append({
            'id': str(menu_item.id),
            'name': menu_item.name,
            'price': item.price,
            'quantity': item.quantity
        })
        
    result = {
        'id': str(order.id),
        'userId': str(order.user_id),
        'serviceType': order.service_type,
        'items': order_items,
        'subtotal': order.subtotal,
        'tax': order.tax,
        'discount': order.discount,
        'total': order.total,
        'status': order.status,
        'createdAt': order.created_at.isoformat()
    }
    
    return jsonify(result), 200

@orders_bp.route('/api/orders/<order_id>', methods=['PUT'])
@token_required
def update_order(current_user, order_id):
    data = request.json
    if not data:
        return jsonify({'message': 'No input data provided'}), 400
    
    order = Order.query.get(order_id)
    
    if not order:
        return jsonify({'message': 'Order not found'}), 404
    
    # Check if the order belongs to the current user
    if order.user_id != current_user.id:
        return jsonify({'message': 'Unauthorized access'}), 403
    
    # Update the order
    if 'serviceType' in data:
        order.service_type = data['serviceType']
    if 'subtotal' in data:
        order.subtotal = data['subtotal']
    if 'tax' in data:
        order.tax = data['tax']
    if 'discount' in data:
        order.discount = data['discount']
    if 'total' in data:
        order.total = data['total']
    if 'status' in data:
        order.status = data['status']
    
    # Update order items if provided
    if 'items' in data:
        # Remove existing order items
        for item in order.items:
            db.session.delete(item)
        
        # Add new order items
        for item_data in data['items']:
            order_item = OrderItem(
                order_id=order.id,
                menu_item_id=int(item_data['id']),
                quantity=item_data.get('quantity', 1),
                price=item_data['price']
            )
            db.session.add(order_item)
    
    db.session.commit()
    
    # Format response
    order_items = []
    for item in order.items:
        menu_item = item.menu_item
        order_items.append({
            'id': str(menu_item.id),
            'name': menu_item.name,
            'price': item.price,
            'quantity': item.quantity
        })
        
    result = {
        'id': str(order.id),
        'userId': str(order.user_id),
        'serviceType': order.service_type,
        'items': order_items,
        'subtotal': order.subtotal,
        'tax': order.tax,
        'discount': order.discount,
        'total': order.total,
        'status': order.status,
        'createdAt': order.created_at.isoformat()
    }
    
    return jsonify(result), 200