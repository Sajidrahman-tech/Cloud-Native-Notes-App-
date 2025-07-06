const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient } = require("@aws-sdk/lib-dynamodb");

// Base DynamoDB client
const client = new DynamoDBClient({});

// Document client wraps the base client for simpler JSON handling
const ddbDocClient = DynamoDBDocumentClient.from(client);

module.exports = { ddbDocClient };
