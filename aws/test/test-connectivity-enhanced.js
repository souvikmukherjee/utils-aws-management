const { Client } = require('pg');
const Redis = require('redis');

// Test PostgreSQL connection
async function testPostgreSQL() {
    console.log('Testing PostgreSQL connection...');
    
    const client = new Client({
        host: process.env.DB_HOST,
        port: process.env.DB_PORT,
        database: process.env.DB_NAME,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        ssl: {
            rejectUnauthorized: false
        },
        connectionTimeoutMillis: 10000,
        query_timeout: 10000
    });
    
    try {
        await client.connect();
        console.log('✅ PostgreSQL connection successful');
        
        const result = await client.query('SELECT NOW() as current_time, version() as version');
        console.log('Current database time:', result.rows[0].current_time);
        console.log('PostgreSQL version:', result.rows[0].version.split(' ')[0]);
        
        await client.end();
    } catch (error) {
        console.error('❌ PostgreSQL connection failed:', error.message);
        console.error('Error details:', error);
    }
}

// Test Redis connection
async function testRedis() {
    console.log('Testing Redis connection...');
    
    const client = Redis.createClient({
        url: process.env.REDIS_URL,
        socket: {
            connectTimeout: 10000,
            commandTimeout: 10000
        }
    });
    
    try {
        await client.connect();
        console.log('✅ Redis connection successful');
        
        await client.set('test_key', 'Hello Redis!');
        const value = await client.get('test_key');
        console.log('Test value from Redis:', value);
        
        // Test Redis info
        const info = await client.info('server');
        console.log('Redis server info:', info.split('\n')[0]);
        
        await client.quit();
    } catch (error) {
        console.error('❌ Redis connection failed:', error.message);
        console.error('Error details:', error);
    }
}

// Load environment variables
require('dotenv').config({ path: '.env.local' });

// Run tests
async function runTests() {
    console.log('🔍 Testing database connections with enhanced error reporting...\n');
    
    console.log('Environment variables:');
    console.log('DB_HOST:', process.env.DB_HOST);
    console.log('DB_PORT:', process.env.DB_PORT);
    console.log('DB_NAME:', process.env.DB_NAME);
    console.log('REDIS_HOST:', process.env.REDIS_HOST);
    console.log('REDIS_PORT:', process.env.REDIS_PORT);
    console.log('');
    
    await testPostgreSQL();
    console.log('');
    await testRedis();
    
    console.log('\n🎉 Connection tests completed!');
}

runTests().catch(console.error);
