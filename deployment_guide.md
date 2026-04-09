# Provus Express Quoting - Deployment Guide

This guide describes how to deploy the Provus Express Quoting application to a fresh Salesforce Scratch Org.

## Prerequisites

- Salesforce CLI installed (`sf` or `sfdx`).
- Authenticated to a Dev Hub.

## Step-by-Step Setup

### 1. Create a Fresh Scratch Org

Run the following command to create a new scratch org with the required features (Quotes, Service Cloud, etc.):

```bash
sf org create scratch -f config/project-scratch-def.json --alias provus-new --set-default --duration-days 30
```

### 2. Deploy Metadata

Deploy the source code, custom objects, and LWCs to the new org:

```bash
sf project deploy start
```

### 3. Assign Permission Sets

Assign the required permissions to your user so you can access the custom objects and fields:

```bash
sf org assign permset -n Provus_Quote_User
sf org assign permset -n Provus_Quote_Manager
```

### 4. Initialize User Role

The application uses a custom role field on the User object for the sidebar and settings logic. Run this script to set your user as an 'Admin':

```bash
sf apex run --file set_admin_role.apex
```

### 5. Load Demo Data

Populate the org with default company settings, sample products, resource roles, and add-ons so you can immediately start quoting:

```bash
sf apex run --file scripts/apex/load_sample_data.apex
```

### 6. Open the App

Launch the org and navigate to the **Provus Quoting** app from the App Launcher:

```bash
sf org open
```

---

## Troubleshooting

- **Quotes Feature**: If you see errors related to the `Quote` object, ensure `quoteSettings.enableQuote` is true in your scratch org (this is handled by step 1).
- **Admin Permissions**: If the Admin Settings tab is missing, ensure you correctly ran Step 4 to set your role to 'Admin'.
