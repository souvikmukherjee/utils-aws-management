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
    });
    
    try {
        await client.connect();
        console.log('✅ PostgreSQL connection successful');
        
        const result = await client.query('SELECT NOW() as current_time');
        console.log('Current database time:', result.rows[0].current_time);
        
        await client.end();
    } catch (error) {
        console.error('❌ PostgreSQL connection failed:', error.message);
    }
}

// Test Redis connection
async function testRedis() {
    console.log('Testing Redis connection...');
    
    const client = Redis.createClient({
        url: process.env.REDIS_URL
    });
    
    try {
        await client.connect();
        console.log('✅ Redis connection successful');
        
        await client.set('test_key', 'Hello Redis!');
        const value = await client.get('test_key');
        console.log('Test value from Redis:', value);
        
        await client.quit();
    } catch (error) {
        console.error('❌ Redis connection failed:', error.message);
    }
}

// Load environment variables
require('dotenv').config({ path: '.env.local' });

// Run tests
async function runTests() {
    console.log('🔍 Testing database connections...\n');
    
    await testPostgreSQL();
    console.log('');
    await testRedis();
    
    console.log('\n🎉 Connection tests completed!');
}

runTests().catch(console.error);
