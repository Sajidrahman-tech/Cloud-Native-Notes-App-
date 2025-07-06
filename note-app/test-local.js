import { handler } from './handler.js';
import fs from 'fs';

// Replace with your test userId
const userId = "sajid123";
let createdNoteId = null;

// Read a test image and convert to base64 (optional)
const imagePath = "./01-.JPG"; // ensure this file exists locally
const imageBase64 = fs.existsSync(imagePath)
  ? fs.readFileSync(imagePath).toString("base64")
  : null;
const imageName = imageBase64 ? "01-.jpg" : null;

const test = async () => {
  console.log("🔹 TEST 1: POST /notes (create a new note)");
  const postEvent = {
    httpMethod: 'POST',
    path: '/notes',
    body: JSON.stringify({
      userId,
      title: "First Note Title",
      content: "This is the content of the first note.",
      imageBase64, // optional
      imageName    // optional
    })
  };
  const postResponse = await handler(postEvent);
  const postResult = JSON.parse(postResponse.body);
  createdNoteId = postResult.note.noteId;
  console.log("✅ POST Response:", postResult);

  console.log("\n🔹 TEST 2: GET /notes/{userId}/{noteId}");
  const getEvent = {
    httpMethod: 'GET',
    path: `/notes/${userId}/${createdNoteId}`
  };
  const getResponse = await handler(getEvent);
  console.log("✅ GET Response:", JSON.parse(getResponse.body));

  console.log("\n🔹 TEST 3: PUT /notes/{userId}/{noteId}");
  const putEvent = {
    httpMethod: 'PUT',
    path: `/notes/${userId}/${createdNoteId}`,
    body: JSON.stringify({
      title: "Updated Note Title",
      content: "This is the updated content."
    })
  };
  const putResponse = await handler(putEvent);
  console.log("✅ PUT Response:", JSON.parse(putResponse.body));

  console.log("\n🔹 TEST 4: GET /notes/{userId}");
  const listEvent = {
    httpMethod: 'GET',
    path: `/notes/${userId}`
  };
  const listResponse = await handler(listEvent);
  console.log("✅ LIST ALL Response:", JSON.parse(listResponse.body));

  console.log("\n🔹 TEST 5: DELETE /notes/{userId}/{noteId}");
  const deleteEvent = {
    httpMethod: 'DELETE',
    path: `/notes/${userId}/${createdNoteId}`
  };
  const deleteResponse = await handler(deleteEvent);
  console.log("✅ DELETE Response:", JSON.parse(deleteResponse.body));

  console.log("\n🔹 TEST 6: GET /test");
  const testEvent = {
    httpMethod: 'GET',
    path: '/test'
  };
  const testResponse = await handler(testEvent);
  console.log("✅ TEST Endpoint:", JSON.parse(testResponse.body));
};

test();
