# Cognito Flask Frontend

A Flask web application with AWS Cognito authentication, designed for deployment on AWS ECS Fargate.

## Features

- User authentication with AWS Cognito (login/logout)
- Session management with secure token handling
- Protected dashboard route
- Health check endpoint for load balancer
- Docker containerization with Gunicorn WSGI server

## Tech Stack

- **Backend**: Python 3.11, Flask
- **Authentication**: AWS Cognito
- **WSGI Server**: Gunicorn
- **Container**: Docker

## Project Structure

```
.
├── app.py                 # Main Flask application
├── templates/
│   ├── base.html          # Base template
│   ├── login.html         # Login page
│   └── dashboard.html     # Protected dashboard
├── Dockerfile             # Container configuration
├── docker-compose.yml     # Local development setup
├── requirements.txt       # Python dependencies
└── .env.example           # Environment variables template
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `COGNITO_USER_POOL_ID` | AWS Cognito User Pool ID |
| `COGNITO_CLIENT_ID` | AWS Cognito App Client ID |
| `COGNITO_CLIENT_SECRET` | AWS Cognito App Client Secret (optional) |
| `AWS_REGION` | AWS Region (default: us-east-1) |
| `FLASK_SECRET_KEY` | Flask session secret key |

## Local Development

1. Copy environment template:
   ```bash
   cp .env.example .env
   ```

2. Fill in your Cognito credentials in `.env`

3. Run with Docker Compose:
   ```bash
   docker-compose up --build
   ```

4. Access the app at `http://localhost:8000`

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Redirects to login or dashboard |
| `/login` | GET, POST | Login page and authentication |
| `/dashboard` | GET | Protected dashboard (requires auth) |
| `/logout` | GET | Clears session and redirects to login |
| `/health` | GET | Health check for load balancer |

## Deployment

This application is designed to be deployed on AWS ECS Fargate. See the [infrastructure repository](https://github.com/Opius-AI/cognito-flask-infrastructure) for CDK deployment code.

### Build for AWS (AMD64)

```bash
docker buildx build --platform linux/amd64 -t flask-auth-app .
```

### Push to ECR

```bash
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-2.amazonaws.com
docker tag flask-auth-app:latest <account-id>.dkr.ecr.us-east-2.amazonaws.com/flask-auth-app:latest
docker push <account-id>.dkr.ecr.us-east-2.amazonaws.com/flask-auth-app:latest
```

## Related Repositories

- [cognito-flask-infrastructure](https://github.com/Opius-AI/cognito-flask-infrastructure) - AWS CDK infrastructure code

## License

MIT
