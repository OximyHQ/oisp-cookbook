# Simple Node.js app for OISP testing
FROM node:20-slim

WORKDIR /app

# Install dependencies
COPY package.json .
RUN npm install

# Copy app
COPY index.js .

# Run app
CMD ["node", "index.js"]
