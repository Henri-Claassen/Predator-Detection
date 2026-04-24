import mysql.connector
import os

conn = mysql.connector.connect(
    host = os.getenv("DB_HOST"),
    port = int(os.getenv("DB_PORT")),
    user = os.getenv("DB_USER"),
    password = os.getenv("DB_PASSWORD"),
    database = os.getenv("DB_NAME")
)

cursor = conn.cursor() #Cursor object to interact with the database

def insert_predator(timeOfDetection, confidenceScore, predatorType, imageData):
    cursor.execute("""
                   INSERT INTO predatorlog 
                   (coopId, deviceId, timeOfDetection, confidenceScore, predatorType, imageData) 
                   VALUES (%s, %s, %s, %s, %s, %s)
                   """, 
                   (1,5, timeOfDetection, confidenceScore, predatorType, imageData) # Use parameterized query to prevent SQL injection
                   )
    conn.commit() # Commit the transaction to save changes to the database
