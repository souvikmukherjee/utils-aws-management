const { Client } = require('pg');
const fs = require('fs');

// Load environment variables
require('dotenv').config({ path: '.env.local' });

async function setupDatabase() {
    console.log('🔧 Setting up database through SSH tunnel...');
    
    // First, connect to default postgres database to create our database
    const adminClient = new Client({
        host: 'localhost',
        port: 5433,
        database: 'postgres',
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        ssl: {
            rejectUnauthorized: false
        }
    });
    
    try {
        await adminClient.connect();
        console.log('✅ Connected to PostgreSQL admin database');
        
        // Create the database if it doesn't exist
        try {
            await adminClient.query('CREATE DATABASE aws_management_dev');
            console.log('✅ Created database: aws_management_dev');
        } catch (error) {
            if (error.code === '42P04') {
                console.log('ℹ️  Database aws_management_dev already exists');
            } else {
                throw error;
            }
        }
        
        await adminClient.end();
        
        // Now connect to our database and set up schema
        const dbClient = new Client({
            host: 'localhost',
            port: 5433,
            database: 'aws_management_dev',
            user: process.env.DB_USER,
            password: process.env.DB_PASSWORD,
            ssl: {
                rejectUnauthorized: false
            }
        });
        
        await dbClient.connect();
        console.log('✅ Connected to aws_management_dev database');
        
        // Read and execute the schema file
        const schemaSQL = fs.readFileSync('setup-database-clean.sql', 'utf8');
        await dbClient.query(schemaSQL);
        console.log('✅ Database schema created successfully');
        
        // Test the setup
        const result = await dbClient.query('SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = \'public\'');
        console.log(`✅ Database setup complete. Found ${result.rows[0].table_count} tables.`);
        
        await dbClient.end();
        
    } catch (error) {
        console.error('❌ Database setup failed:', error.message);
        throw error;
    }
}

async function testRedis() {
    console.log('\n🔍 Testing Redis connection through tunnel...');
    
    const Redis = require('redis');
    const client = Redis.createClient({
        host: 'localhost',
        port: 6380,
        socket: {
            connectTimeout: 10000
        }
    });
    
    try {
        await client.connect();
        console.log('✅ Redis connection successful through tunnel');
        
        await client.set('test_key', 'Hello Redis through tunnel!');
        const value = await client.get('test_key');
        console.log('Test value from Redis:', value);
        
        await client.quit();
    } catch (error) {
        console.error('❌ Redis connection failed:', error.message);
    }
}

async function runSetup() {
    try {
        await setupDatabase();
        await testRedis();
        
        console.log('\n🎉 Database and Redis setup completed successfully!');
        console.log('\n📋 You can now use the databases through the SSH tunnel:');
        console.log('PostgreSQL: localhost:5433');
        console.log('Redis: localhost:6380');
        
    } catch (error) {
        console.error('\n❌ Setup failed:', error);
        process.exit(1);
    }
}

runSetup(); 