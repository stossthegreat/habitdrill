# Drillos Backend

A production-ready backend API built with TypeScript, Fastify, Prisma, Redis, and BullMQ, designed to scale to millions of users.

## 🚀 Features

- **Fastify** - High-performance web framework
- **TypeScript** - Type-safe development
- **Prisma** - Modern database ORM with PostgreSQL
- **Redis** - Caching and session storage
- **BullMQ** - Background job processing
- **Swagger/OpenAPI** - Auto-generated API documentation
- **Graceful shutdown** - Production-ready error handling
- **Scalable architecture** - Built for millions of users

## 📁 Project Structure

```
backend/
├── prisma/
│   └── schema.prisma          # Database schema
├── src/
│   ├── controllers/           # Route controllers
│   ├── services/             # Business logic
│   ├── utils/                # Utilities (database, redis, queue)
│   ├── jobs/                 # Background job workers
│   └── server.ts             # Main server file
├── .env                      # Environment variables
├── .gitignore               # Git ignore rules
├── package.json             # Dependencies and scripts
└── tsconfig.json            # TypeScript configuration
```

## 🛠️ Setup

### Prerequisites

- Node.js 18+ 
- PostgreSQL 13+
- Redis 6+

### Installation

1. **Clone and navigate to the backend directory:**
   ```bash
   cd backend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Set up environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env with your actual values
   ```

4. **Set up the database:**
   ```bash
   # Update DATABASE_URL in .env with your PostgreSQL connection string
   npm run prisma:migrate
   ```

5. **Generate Prisma client:**
   ```bash
   npm run prisma:generate
   ```

### Environment Variables

Create a `.env` file with the following variables:

```env
# Database
DATABASE_URL="postgresql://username:password@localhost:5432/drillos_db?schema=public"

# Redis
REDIS_URL="redis://localhost:6379"

# API Keys
OPENAI_API_KEY="your_openai_api_key_here"
STRIPE_SECRET_KEY="your_stripe_secret_key_here"
STRIPE_PUBLISHABLE_KEY="your_stripe_publishable_key_here"

# Firebase
FIREBASE_PROJECT_ID="your_firebase_project_id"
FIREBASE_PRIVATE_KEY="your_firebase_private_key"
FIREBASE_CLIENT_EMAIL="your_firebase_client_email"

# Server
PORT=3000
NODE_ENV=development

# JWT
JWT_SECRET="your_jwt_secret_here"

# BullMQ
BULLMQ_REDIS_URL="redis://localhost:6379"

# Logging
LOG_BATCH_SIZE=50  # Default: 50 (batch size for job scheduling logs)

# Future-You Unified Engine
FUTUREYOU_ENABLED=true  # Default: true (set to 'false' to disable)
FUTUREYOU_AI_MODEL=gpt-5-mini
FUTUREYOU_MAX_TOKENS=900
FUTUREYOU_TEMPERATURE=0.7
FUTUREYOU_CACHE_TTL_SEC=86400
```

## 🚀 Running the Application

### Development

```bash
npm run dev
```

### Production

```bash
npm run build
npm start
```

## 📚 API Documentation

Once the server is running, visit:
- **API Documentation**: http://localhost:3000/docs
- **Health Check**: http://localhost:3000/health
- **API Status**: http://localhost:3000/api/v1/status

## 🔧 Available Scripts

- `npm run dev` - Start development server with hot reload
- `npm run build` - Build for production
- `npm start` - Start production server
- `npm run prisma:generate` - Generate Prisma client
- `npm run prisma:migrate` - Run database migrations

## 🏗️ Database Schema

The application uses the following main entities:

- **User** - User accounts with preferences
- **Habit** - Positive habits to build
- **AntiHabit** - Habits to break
- **Alarm** - Scheduled reminders
- **Event** - User activity tracking
- **UserFacts** - User profile information
- **VoiceCache** - Cached voice generation

## 🔄 Background Jobs

The application uses BullMQ for background job processing:

- **Email Queue** - Send welcome emails, reminders
- **Notification Queue** - Push notifications
- **Analytics Queue** - Process user analytics
- **Voice Queue** - Generate voice content

## 🚀 Production Deployment

### Docker (Recommended)

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm", "start"]
```

### Environment Setup

1. **Database**: Set up PostgreSQL with connection pooling
2. **Redis**: Configure Redis cluster for high availability
3. **Load Balancer**: Use nginx or cloud load balancer
4. **Monitoring**: Set up logging and monitoring (e.g., DataDog, New Relic)

### Scaling Considerations

- **Database**: Use read replicas and connection pooling
- **Redis**: Set up Redis cluster for high availability
- **Background Jobs**: Scale workers horizontally
- **API**: Use load balancers and multiple instances

## 🔒 Security

- Input validation with Fastify schemas
- CORS configuration
- Environment variable protection
- Database connection security
- Rate limiting (recommended for production)

## 📊 Monitoring

- Health check endpoints
- Database connection monitoring
- Redis connection monitoring
- Queue health checks
- Graceful shutdown handling

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the ISC License.
