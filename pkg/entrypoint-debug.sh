#!/bin/bash

# Enhanced entrypoint script with better error handling and debugging
set -e

echo "🔧 Starting AISecurity Profile API with enhanced debugging..."
echo "📅 Timestamp: $(date)"
echo "🏠 Working directory: $(pwd)"
echo "📁 Directory contents:"
ls -la /app/

# Function to handle errors
handle_error() {
    echo "❌ Error occurred in entrypoint script"
    echo "📍 Error location: $1"
    echo "💭 Error details: $2"
    echo "🔍 Current environment variables:"
    env | grep -E "(DB_|PYTHON|PATH)" | sort
    echo "⏰ Sleeping for 300 seconds to allow debugging..."
    sleep 300
    exit 1
}

# Trap errors
trap 'handle_error "${LINENO}" "${BASH_COMMAND}"' ERR

echo "🔧 Configuring database connection..."

# Check if we need to override DB settings
if [ -n "$DB_ADDR" ] || [ -n "$DB_ACCOUNT" ] || [ -n "$DB_CREDENT" ] || [ -n "$DB_NAME" ]; then
    echo "📝 Updating database configuration with environment variables..."
    
    # Export environment variables for the new database manager
    if [ -n "$DB_ADDR" ]; then
        echo "   - Setting MONGODB_HOST to: $DB_ADDR"
        export MONGODB_HOST="$DB_ADDR"
    fi
    
    if [ -n "$DB_ACCOUNT" ]; then
        # Decode base64 username for k3d environment
        DECODED_USERNAME=$(echo "$DB_ACCOUNT" | base64 -d 2>/dev/null || echo "$DB_ACCOUNT")
        echo "   - Setting MONGODB_USERNAME to: $DECODED_USERNAME"
        export MONGODB_USERNAME="$DECODED_USERNAME"
    fi
    
    if [ -n "$DB_CREDENT" ]; then
        # Decode base64 password for k3d environment
        DECODED_PASSWORD=$(echo "$DB_CREDENT" | base64 -d 2>/dev/null || echo "$DB_CREDENT")
        echo "   - Setting MONGODB_PASSWORD to: [REDACTED]"
        export MONGODB_PASSWORD="$DECODED_PASSWORD"
    fi
    
    if [ -n "$DB_NAME" ]; then
        echo "   - Setting MONGODB_DATABASE to: $DB_NAME"
        export MONGODB_DATABASE="$DB_NAME"
    fi
    
    echo "✅ Database configuration exported to environment variables!"
else
    echo "ℹ️  Using default database configuration"
fi

# Test Python path and imports
echo "🐍 Testing Python environment..."
python3 -c "
import sys
print('Python version:', sys.version)
print('Python path:', sys.path)
sys.path.append('/app')

# Test basic imports
try:
    import fastapi
    print('✅ FastAPI imported successfully')
except Exception as e:
    print('❌ FastAPI import failed:', e)
    sys.exit(1)

try:
    import uvicorn
    print('✅ Uvicorn imported successfully')
except Exception as e:
    print('❌ Uvicorn import failed:', e)
    sys.exit(1)

try:
    from api import main
    print('✅ API main module imported successfully')
except Exception as e:
    print('❌ API main module import failed:', e)
    print('Available files in /app/api/:')
    import os
    try:
        print(os.listdir('/app/api/'))
    except:
        print('api directory not accessible')
    sys.exit(1)
" || handle_error "${LINENO}" "Python environment test failed"

# Test database connection (non-blocking)
echo "🔍 Testing database connection..."
python3 -c "
import sys
sys.path.append('/app')
try:
    from lib.db_connector import connect_database
    connected, client, error = connect_database()
    if connected:
        print('✅ Database connection successful!')
        print('   - Connected to MongoDB')
    else:
        print('⚠️  Database connection failed:', error)
        print('   - Service will start anyway, connection will be retried')
except Exception as e:
    print('⚠️  Database connection test failed:', str(e))
    print('   - Service will start anyway')
" || echo "⚠️  Database test failed, continuing anyway..."

# Final checks
echo "🔍 Final pre-flight checks..."
echo "   - Current working directory: $(pwd)"
echo "   - Available directories:"
ls -la /app/ | head -10
echo "   - Python executable: $(which python3)"
echo "   - Command to execute: $@"

echo "🚀 Starting AISecurity Profile API..."
exec "$@"