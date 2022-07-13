const express = require('express');
const { createRemoteJWKSet } = require('jose');
const { secure } = require('express-oauth-jwt');

const app = express();
const port = 3000;

// internal runtime url for intra cluster communication
const jwksService = createRemoteJWKSet(new URL('http://curity-idsvr-runtime-svc.curity.svc.cluster.local:8443/~/jwks'));

// Configure OAuth security to validate JWTs and to check the issuer + audience claims
const validationOptions = {
  claims: [
    {
      name: 'iss',
      value: process.env.ISSUER // set from simple-echo-api-k8s-deployment.yaml
    },
    {
      name: 'aud',
      value: 'simple-echo-api'
    }
  ],
  scope: ['read']
};

const middleware = secure(jwksService, validationOptions);

app.get('/echo', middleware, (req, res) => {
  const token = req.headers.authorization.replace('Bearer ', '');
  console.log(`JWT token echoed back from the upstream API = ${token}`);

  const message = `API called with the scope '${req.claims.scope}'`;
  const data = {
    token,
    message
  };

  res.status(200).send(JSON.stringify(data));
});

app.listen(port, () => console.log(`Simple Echo API listening on port : ${port}`));
