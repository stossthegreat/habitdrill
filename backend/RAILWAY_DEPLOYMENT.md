# Railway Deployment Guide

## 🚀 Quick Setup

1. **Connect your repository to Railway**
2. **Set the following environment variables in Railway dashboard:**

### Required Environment Variables

```bash
# Database (Railway PostgreSQL addon will provide this)
DATABASE_URL=postgresql://...

# Redis (Railway Redis addon will provide this)
REDIS_URL=redis://...

# OpenAI Configuration
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_MODEL=gpt-4o-mini

# ElevenLabs Configuration
ELEVENLABS_API_KEY=your_elevenlabs_api_key_here
ELEVENLABS_VOICE_MARCUS=your_voice_id_here
ELEVENLABS_VOICE_DRILL=your_voice_id_here
ELEVENLABS_VOICE_CONFUCIUS=your_voice_id_here
ELEVENLABS_VOICE_LINCOLN=your_voice_id_here
ELEVENLABS_VOICE_BUDDHA=your_voice_id_here

# Firebase Configuration
FIREBASE_PROJECT_ID=your_firebase_project_id
FIREBASE_CLIENT_EMAIL=your_firebase_client_email
FIREBASE_PRIVATE_KEY=your_firebase_private_key

# Stripe Configuration
STRIPE_SECRET_KEY=your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=your_stripe_webhook_secret

# S3 Configuration
S3_ENDPOINT=your_s3_endpoint
S3_BUCKET=your_s3_bucket_name
S3_ACCESS_KEY=your_s3_access_key
S3_SECRET_KEY=your_s3_secret_key

# Server Configuration
PORT=8080
HOST=0.0.0.0
NODE_ENV=production

# Logging Configuration (Optional)
LOG_BATCH_SIZE=50
```

## 🔧 Railway Configuration

The following files have been configured for Railway:

- `railway.json` - Railway build configuration
- `.nvmrc` - Node.js version specification
- Updated `package.json` build script
- Updated `Dockerfile` for production builds
- Modified environment validation in `server.ts`

## 🚨 Common Issues & Solutions

### Build Fails with "Missing required env vars"
- **Solution**: The environment validation now skips during build process
- **Note**: Make sure to set all required environment variables in Railway dashboard

### Prisma Generate Fails
- **Solution**: Updated build script to run `prisma generate` after TypeScript compilation
- **Note**: Prisma client is now generated during the build process

### TypeScript Compilation Errors
- **Solution**: Check your TypeScript code for any type errors
- **Note**: Run `npm run build` locally to test compilation

### Database Connection Issues
- **Solution**: Ensure `DATABASE_URL` is set correctly in Railway
- **Note**: Railway PostgreSQL addon provides this automatically

## 📊 Monitoring

After deployment, check these endpoints:

- **Health Check**: `https://your-app.railway.app/health`
- **Startup Check**: `https://your-app.railway.app/startup-check`
- **API Docs**: `https://your-app.railway.app/docs`

## 🔄 Deployment Process

1. Railway will automatically:
   - Install dependencies (`npm ci --only=production`)
   - Build TypeScript (`npm run build`)
   - Generate Prisma client
   - Run database migrations (`npx prisma migrate deploy`)
   - Start the server (`node dist/server.js`)

2. Monitor the deployment logs for any errors

## 🆘 Troubleshooting

If deployment fails:

1. Check Railway build logs for specific error messages
2. Verify all environment variables are set correctly
3. Ensure your database and Redis services are running
4. Check that all API keys are valid and have proper permissions

## 📝 Notes

- The app uses PostgreSQL and Redis - make sure to add these services in Railway
- Environment validation is skipped during build to prevent build failures
- Prisma migrations run automatically on startup
- The app includes health checks and startup validation
