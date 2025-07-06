const { v4: uuidv4 } = require('uuid');
const {
  GetCommand,
  PutCommand,
  UpdateCommand,
  DeleteCommand,
  QueryCommand
} = require("@aws-sdk/lib-dynamodb");

const { ddbDocClient } = require("./utils/dynamodbClient");

const { S3Client, PutObjectCommand, GetObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");

const s3 = new S3Client({ region: "us-east-1" });
const BUCKET_NAME = "note-app-images-sajid12345";
const TABLE_NAME = "NotesTable";

const handler = async (event) => {
  const method = event.httpMethod;
  const path = event.path;

  try {
    if (method === "POST" && path === "/notes") {
      const { userId, title, content, imageBase64, imageName } = JSON.parse(event.body);

      if (!userId || !title || !content) {
        return respond(400, { message: "Missing userId, title, or content" });
      }

      let imageUrl = null;

      if (imageBase64 && imageName) {
        try {
          const buffer = Buffer.from(imageBase64, "base64");
          const s3Key = `${userId}/${Date.now()}-${imageName}`;

          await s3.send(new PutObjectCommand({
            Bucket: BUCKET_NAME,
            Key: s3Key,
            Body: buffer,
            ContentType: "image/jpeg"
          }));

          const command = new GetObjectCommand({
            Bucket: BUCKET_NAME,
            Key: s3Key
          });

          imageUrl = await getSignedUrl(s3, command, { expiresIn: 3600 });
        } catch (err) {
          console.error("S3 Upload Error:", err);
          return respond(500, { message: "Image upload failed", error: err.message });
        }
      }

      const noteId = uuidv4();
      const note = {
        userId,
        noteId,
        title,
        content,
        imageUrl,
        createdAt: new Date().toISOString()
      };

      await ddbDocClient.send(new PutCommand({
        TableName: TABLE_NAME,
        Item: note
      }));

      return respond(201, { message: "Note created", note });
    }

    else if (method === "GET" && path.split("/").length === 3) {
      const [, , userId] = path.split("/");
      const result = await ddbDocClient.send(new QueryCommand({
        TableName: TABLE_NAME,
        KeyConditionExpression: "userId = :uid",
        ExpressionAttributeValues: { ":uid": userId }
      }));
      return respond(200, { notes: result.Items || [] });
    }

    else if (method === "GET" && path.split("/").length === 4) {
      const [, , userId, noteId] = path.split("/");
      const result = await ddbDocClient.send(new GetCommand({
        TableName: TABLE_NAME,
        Key: { userId, noteId }
      }));
      if (!result.Item) return respond(404, { message: "Note not found" });
      return respond(200, result.Item);
    }

    else if (method === "PUT" && path.split("/").length === 4) {
      const [, , userId, noteId] = path.split("/");
      const { title, content } = JSON.parse(event.body);

      if (!title || !content) {
        return respond(400, { message: "Missing title or content" });
      }

      await ddbDocClient.send(new UpdateCommand({
        TableName: TABLE_NAME,
        Key: { userId, noteId },
        UpdateExpression: "set title = :title, content = :content",
        ExpressionAttributeValues: {
          ":title": title,
          ":content": content
        }
      }));

      return respond(200, { message: "Note updated" });
    }

    else if (method === "DELETE" && path.split("/").length === 4) {
      const [, , userId, noteId] = path.split("/");
      await ddbDocClient.send(new DeleteCommand({
        TableName: TABLE_NAME,
        Key: { userId, noteId }
      }));
      return respond(200, { message: "Note deleted successfully" });
    }

    else if (method === "GET" && path === "/test") {
      return respond(200, { message: "Note-taking API is working!" });
    }

    else {
      return respond(404, { message: "Route not found" });
    }

  } catch (err) {
    console.error("💥 Error occurred:", err);
    return respond(500, {
      message: "Internal Server Error",
      error: err.message,
      stack: err.stack
    });
  }
};

const respond = (statusCode, body) => ({
  statusCode,
  headers: {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS"
  },
  body: JSON.stringify(body)
});

module.exports = { handler };
