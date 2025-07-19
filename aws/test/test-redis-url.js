const Redis = require('redis');

async function testRedis() {
    console.log('Testing Redis connection using URL format...');
    
    const client = Redis.createClient({
        url: 'redis://localhost:6380',
        socket: {
            connectTimeout: 10000,
            commandTimeout: 10000
        }
    });
    
    try {
        console.log('Attempting to connect to Redis using URL: redis://localhost:6380');
        await client.connect();
        console.log('✅ Redis connection successful!');
        
        await client.set('test_key', 'Hello Redis through tunnel!');
        const value = await client.get('test_key');
        console.log('Test value from Redis:', value);
        
        await client.quit();
        console.log('✅ Redis test completed successfully!');
        
    } catch (error) {
        console.error('❌ Redis connection failed:', error.message);
        console.error('Error details:', error);
    }
}

testRedis(); 