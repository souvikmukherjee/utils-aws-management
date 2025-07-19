const { Client } = require('pg');

// Load environment variables
require('dotenv').config({ path: '.env.local' });

async function testConnection() {
    console.log('Testing direct database connection...');
    console.log('DB_NAME:', process.env.DB_NAME);
    console.log('DB_HOST:', process.env.DB_HOST);
    console.log('DB_PORT:', process.env.DB_PORT);
    
    const client = new Client({
        host: 'localhost',
        port: 5433,
        database: 'aws_management_dev', // Use the actual database name
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        ssl: {
            rejectUnauthorized: false
        }
    });
    
    try {
        await client.connect();
        console.log('✅ Connected successfully!');
        
        const result = await client.query('SELECT NOW() as current_time');
        console.log('Current time:', result.rows[0].current_time);
        
        const tables = await client.query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'");
        console.log('Tables found:', tables.rows.map(row => row.table_name));
        
        await client.end();
    } catch (error) {
        console.error('❌ Connection failed:', error.message);
    }
}

testConnection(); 