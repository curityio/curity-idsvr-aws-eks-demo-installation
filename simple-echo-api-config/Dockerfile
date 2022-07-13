FROM node:16-slim
# Create app directory
WORKDIR /usr/src/app

COPY package*.json ./

RUN npm ci --only=production

# Bundle app source
COPY api.js ./

CMD [ "node", "api.js" ]