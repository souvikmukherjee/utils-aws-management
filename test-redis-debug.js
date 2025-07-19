const Redis = require('redis');

async function testRedis() {
    console.log('Testing Redis connection with debug info...');
    
    const config = {
        host: 'localhost',
        port: 6380,
        socket: {
            connectTimeout: 10000,
            commandTimeout: 10000
        }
    };
    
    console.log('Redis config:', JSON.stringify(config, null, 2));
    
    const client = Redis.createClient(config);
    
    try {
        console.log('Attempting to connect to Redis...');
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
        
        // Try to get more info about the connection
        console.log('\nDebug info:');
        console.log('Redis client config:', client.options);
    }
}

testRedis(); 