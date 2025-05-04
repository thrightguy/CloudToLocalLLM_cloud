// Mock License Verification API
// This is a simple mock for development purposes

const express = require('express');
const bodyParser = require('body-parser');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(bodyParser.json());

// Sample private key (for development only)
// In production, these would be stored securely
// The actual keys would be longer and properly generated
const PRIVATE_KEY = `
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC98MNf2TSCIma9
DEVELOPMENT_PRIVATE_KEY_GOES_HEREqRX/ygwcBEQtVs1rJm2Q+m6+sBBK2fobELB
tlH8mwuUU8vwLcF0baJ1QgzWXGf/NhFEZ49xUyxWvg3oEX4cZ+3/gHdQUERC2k0K
QmlKfFcMlcHWDzKzjH7tR0E6AGZEuBMe3KOwIDAQAB
-----END PRIVATE KEY-----
`.trim();

// Sample license data store (in-memory for demo)
// In production, this would be a database
const licenses = {
  'FREE-TRIAL-KEY-123456': {
    id: 'lic_free_trial_001',
    customerId: 'cus_trial_user',
    licenseKeyHash: crypto.createHash('sha256').update('FREE-TRIAL-KEY-123456').digest('hex'),
    tier: 'trial',
    status: 'active',
    expiryDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(), // 30 days
    features: ['basic_models', 'single_container'],
    maxContainers: 1,
    maxDevices: 1,
    createdAt: new Date().toISOString(),
  },
  'DEV-LICENSE-234567': {
    id: 'lic_dev_001',
    customerId: 'cus_dev_user',
    licenseKeyHash: crypto.createHash('sha256').update('DEV-LICENSE-234567').digest('hex'),
    tier: 'developer',
    status: 'active',
    expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(), // 1 year
    features: ['basic_models', 'advanced_models', 'multi_container', 'cloud_sync'],
    maxContainers: 3,
    maxDevices: 2,
    createdAt: new Date().toISOString(),
  },
  'PRO-LICENSE-345678': {
    id: 'lic_pro_001',
    customerId: 'cus_pro_user',
    licenseKeyHash: crypto.createHash('sha256').update('PRO-LICENSE-345678').digest('hex'),
    tier: 'professional',
    status: 'active',
    expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(), // 1 year
    features: ['basic_models', 'advanced_models', 'multi_container', 'cloud_sync', 'team_collab', 'api_access'],
    maxContainers: 10,
    maxDevices: 5,
    createdAt: new Date().toISOString(),
  },
  'ENT-LICENSE-456789': {
    id: 'lic_ent_001',
    customerId: 'cus_ent_user',
    licenseKeyHash: crypto.createHash('sha256').update('ENT-LICENSE-456789').digest('hex'),
    tier: 'enterprise',
    status: 'active',
    expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(), // 1 year
    features: ['basic_models', 'advanced_models', 'multi_container', 'cloud_sync', 'team_collab', 'api_access', 'custom_domain', 'audit_logs', 'sso'],
    maxContainers: 50,
    maxDevices: 25,
    createdAt: new Date().toISOString(),
  },
};

// Track device usage
const deviceUsage = {};

// Simple signature function (for demo only)
// In production, this would use proper asymmetric encryption
function signData(data) {
  // Create a signature using the private key
  // This is simplified - production would use proper RSA/ECDSA signing
  const signature = 'SIGNED_' + crypto.createHash('sha256').update(JSON.stringify(data)).digest('hex');
  return signature;
}

// API endpoint for license verification
app.post('/v1/license/verify', (req, res) => {
  console.log('License verification request received:', req.body);
  
  const { licenseKey, deviceId, appVersion, usageMetrics } = req.body;
  
  // Check if license key exists
  if (!licenseKey || !licenses[licenseKey]) {
    return res.status(401).json({
      status: 'error',
      message: 'Invalid license key',
    });
  }
  
  const license = licenses[licenseKey];
  
  // Check if license is active
  if (license.status !== 'active') {
    return res.status(401).json({
      status: 'error',
      message: 'License is not active',
    });
  }
  
  // Check if license is expired
  if (new Date(license.expiryDate) < new Date()) {
    return res.status(401).json({
      status: 'error',
      message: 'License has expired',
    });
  }
  
  // Track device usage (simplified)
  if (!deviceUsage[licenseKey]) {
    deviceUsage[licenseKey] = new Set();
  }
  
  deviceUsage[licenseKey].add(deviceId);
  
  // Check device limit
  if (deviceUsage[licenseKey].size > license.maxDevices) {
    return res.status(401).json({
      status: 'error',
      message: 'Maximum device limit reached',
    });
  }
  
  // Create response with license data
  const responseData = {
    id: license.id,
    customerId: license.customerId,
    licenseKeyHash: license.licenseKeyHash,
    tier: license.tier,
    status: license.status,
    expiryDate: license.expiryDate,
    features: license.features,
    maxContainers: license.maxContainers,
    maxDevices: license.maxDevices,
    createdAt: license.createdAt,
  };
  
  // Add signature
  responseData.signature = signData(responseData);
  
  console.log('License verified successfully');
  
  // Return the response
  return res.status(200).json(responseData);
});

// Start server
app.listen(PORT, () => {
  console.log(`License verification API mock running on port ${PORT}`);
});

// For easy testing, print the license keys
console.log('Available test license keys:');
Object.keys(licenses).forEach(key => {
  console.log(`- ${key} (${licenses[key].tier} tier)`);
}); 