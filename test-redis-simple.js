const Redis = require('redis');

async function testRedis() {
    console.log('Testing Redis connection...');
    
    const client = Redis.createClient({
        host: 'localhost',
        port: 6380,
        socket: {
            connectTimeout: 10000,
            commandTimeout: 10000
        }
    });
    
    try {
        console.log('Attempting to connect...');
        await client.connect();
        console.log('✅ Redis connection successful!');
        
        console.log('Setting test key...');
        await client.set('test_key', 'Hello Redis!');
        
        console.log('Getting test key...');
        const value = await client.get('test_key');
        console.log('Test value:', value);
        
        console.log('Getting Redis info...');
        const info = await client.info('server');
        console.log('Redis server info:', info.split('\n')[0]);
        
        await client.quit();
        console.log('✅ Redis test completed successfully!');
        
    } catch (error) {
        console.error('❌ Redis connection failed:', error.message);
        console.error('Error details:', error);
    }
}

testRedis(); 