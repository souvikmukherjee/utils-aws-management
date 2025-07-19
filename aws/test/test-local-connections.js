const { Client } = require('pg');
const Redis = require('redis');

// Load environment variables
require('dotenv').config({ path: '.env.local' });

// Test PostgreSQL connection through tunnel
async function testPostgreSQL() {
    console.log('Testing PostgreSQL connection through SSH tunnel...');
    
    const client = new Client({
        host: 'localhost',
        port: 5433, // Local tunnel port
        database: 'aws_management_dev', // Use the actual database name
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        ssl: {
            rejectUnauthorized: false
        },
        connectionTimeoutMillis: 10000
    });
    
    try {
        await client.connect();
        console.log('✅ PostgreSQL connection successful through tunnel');
        
        const result = await client.query('SELECT NOW() as current_time, version() as version');
        console.log('Current database time:', result.rows[0].current_time);
        console.log('PostgreSQL version:', result.rows[0].version.split(' ')[0]);
        
        await client.end();
    } catch (error) {
        console.error('❌ PostgreSQL connection failed:', error.message);
    }
}

// Test Redis connection through tunnel
async function testRedis() {
    console.log('Testing Redis connection through SSH tunnel...');
    
    const client = Redis.createClient({
        url: 'redis://localhost:6380',
        socket: {
            connectTimeout: 10000,
            commandTimeout: 10000
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
        console.error('Error details:', error);
    }
}

// Run tests
async function runTests() {
    console.log('🔍 Testing database connections through SSH tunnel...\n');
    
    await testPostgreSQL();
    console.log('');
    await testRedis();
    
    console.log('\n🎉 Tunnel connection tests completed!');
}

runTests().catch(console.error);
