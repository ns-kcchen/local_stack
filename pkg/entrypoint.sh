#!/bin/bash

# Entrypoint script to configure database connection based on environment variables
set -e

echo "🔧 Configuring database connection..."

# Set PUSH_NOW to False for k3d local cluster environment
export PUSH_NOW="False"
echo "📝 Setting PUSH_NOW=False for k3d local cluster environment"

# Check if we need to override DB settings
if [ -n "$DB_ADDR" ] || [ -n "$DB_ACCOUNT" ] || [ -n "$DB_CREDENT" ] || [ -n "$DB_NAME" ]; then
    echo "📝 Configuring database connection with environment variables..."
    
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

# Test database connection
echo "🔍 Testing database connection..."
python3 -c "
import sys
import os
sys.path.append('/app/src/aisecurity-profile-api/lib')
sys.path.append('/app/src/aisecurity-profile-api/api')

# Set SKIP_MONGODB for testing to avoid connection attempts during import
original_skip = os.environ.get('SKIP_MONGODB')
os.environ['SKIP_MONGODB'] = 'false'  # Enable MongoDB connection for testing

try:
    from database_manager import database_manager
    
    # Test database connection
    status = database_manager.check_database_status()
    if status.get('connected', False):
        print('✅ Database connection successful!')
        print(f'   - Connected to MongoDB: {status.get(\"database_name\", \"Unknown\")}')
        print(f'   - Using connector: {status.get(\"connector_type\", \"Unknown\")}')
    else:
        print('⚠️  Database connection failed:', status.get('message', 'Unknown error'))
        print('   - Service will start anyway, connection will be retried')
except Exception as e:
    print('⚠️  Database connection test failed:', str(e))
    print('   - Service will start anyway')

# Restore original SKIP_MONGODB setting
if original_skip is not None:
    os.environ['SKIP_MONGODB'] = original_skip
elif 'SKIP_MONGODB' in os.environ:
    del os.environ['SKIP_MONGODB']
"

echo "🚀 Starting AISecurity Profile API..."
exec "$@"