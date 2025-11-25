import os
from flask import Flask, render_template, request, redirect, url_for, session, flash
import boto3
from botocore.exceptions import ClientError
from functools import wraps
import hmac
import hashlib
import base64

app = Flask(__name__)
app.secret_key = os.environ.get('FLASK_SECRET_KEY', 'dev-secret-key-change-in-production')

# AWS Cognito configuration
COGNITO_USER_POOL_ID = os.environ.get('COGNITO_USER_POOL_ID')
COGNITO_CLIENT_ID = os.environ.get('COGNITO_CLIENT_ID')
COGNITO_CLIENT_SECRET = os.environ.get('COGNITO_CLIENT_SECRET')
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')

# Initialize Cognito client
cognito_client = boto3.client('cognito-idp', region_name=AWS_REGION)


def get_secret_hash(username):
    """Generate secret hash for Cognito authentication"""
    if not COGNITO_CLIENT_SECRET:
        return None

    message = bytes(username + COGNITO_CLIENT_ID, 'utf-8')
    secret = bytes(COGNITO_CLIENT_SECRET, 'utf-8')
    dig = hmac.new(secret, message, hashlib.sha256).digest()
    return base64.b64encode(dig).decode()


def login_required(f):
    """Decorator to protect routes that require authentication"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'access_token' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function


@app.route('/')
def index():
    """Home page - redirects to login or dashboard"""
    if 'access_token' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))


@app.route('/login', methods=['GET', 'POST'])
def login():
    """Login page and authentication handler"""
    if request.method == 'POST':
        email = request.form.get('email')
        password = request.form.get('password')

        if not email or not password:
            flash('Please provide both email and password', 'error')
            return render_template('login.html')

        try:
            # Prepare authentication parameters
            auth_params = {
                'USERNAME': email,
                'PASSWORD': password
            }

            # Add SECRET_HASH if client secret is configured
            secret_hash = get_secret_hash(email)
            if secret_hash:
                auth_params['SECRET_HASH'] = secret_hash

            # Authenticate with Cognito
            response = cognito_client.initiate_auth(
                ClientId=COGNITO_CLIENT_ID,
                AuthFlow='USER_PASSWORD_AUTH',
                AuthParameters=auth_params
            )

            # Store tokens in session
            session['access_token'] = response['AuthenticationResult']['AccessToken']
            session['id_token'] = response['AuthenticationResult']['IdToken']
            session['refresh_token'] = response['AuthenticationResult']['RefreshToken']
            session['user_email'] = email

            flash('Login successful!', 'success')
            return redirect(url_for('dashboard'))

        except ClientError as e:
            error_code = e.response['Error']['Code']

            if error_code == 'NotAuthorizedException':
                flash('Incorrect email or password', 'error')
            elif error_code == 'UserNotFoundException':
                flash('User not found', 'error')
            elif error_code == 'UserNotConfirmedException':
                flash('Please verify your email address', 'error')
            else:
                flash(f'Authentication error: {e.response["Error"]["Message"]}', 'error')

        except Exception as e:
            flash(f'An error occurred: {str(e)}', 'error')

    return render_template('login.html')


@app.route('/dashboard')
@login_required
def dashboard():
    """Protected dashboard page"""
    user_email = session.get('user_email', 'User')
    return render_template('dashboard.html', user_email=user_email)


@app.route('/logout')
def logout():
    """Logout handler"""
    session.clear()
    flash('You have been logged out', 'success')
    return redirect(url_for('login'))


@app.route('/health')
def health():
    """Health check endpoint"""
    return {'status': 'healthy'}, 200


if __name__ == '__main__':
    # Check if required environment variables are set
    if not COGNITO_USER_POOL_ID or not COGNITO_CLIENT_ID:
        print("WARNING: COGNITO_USER_POOL_ID and COGNITO_CLIENT_ID must be set")

    app.run(host='0.0.0.0', port=8000, debug=os.environ.get('FLASK_DEBUG', 'False') == 'True')
