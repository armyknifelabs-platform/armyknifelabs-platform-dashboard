# GitHub Repository Secrets Checklist

Before pushing to GitHub, ensure these secrets are configured in **Settings → Secrets and variables → Actions**.

## Required Secrets

### AWS Credentials
- [ ] `AWS_ACCESS_KEY_ID` - AWS access key for deployments
- [ ] `AWS_SECRET_ACCESS_KEY` - AWS secret access key

## Quick Setup Commands

### 1. Create IAM User (if needed)

```bash
# Create user
aws iam create-user --user-name github-actions-seip

# Attach policies
aws iam attach-user-policy \
  --user-name github-actions-seip \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

aws iam attach-user-policy \
  --user-name github-actions-seip \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess

aws iam attach-user-policy \
  --user-name github-actions-seip \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite

# Create access key
aws iam create-access-key --user-name github-actions-seip
```

### 2. Add Secrets to GitHub

1. Go to: `https://github.com/YOUR_ORG/YOUR_REPO/settings/secrets/actions`
2. Click **New repository secret**
3. Add:
   - **Name**: `AWS_ACCESS_KEY_ID`
   - **Value**: `<access-key-from-above>`
4. Click **Add secret**
5. Repeat for `AWS_SECRET_ACCESS_KEY`

## Verify Secrets

After adding secrets, verify they work:

1. Go to **Actions** → **CI - Build and Test**
2. Click **Run workflow**
3. Check if workflow completes successfully

## Production Secrets (AWS Secrets Manager)

These are already configured in AWS Secrets Manager:

- ✅ `seip/production/database/password` - Production database password
- ✅ `default-tenant/credentials/anthropic` - Anthropic API key
- ✅ `default-tenant/credentials/openai` - OpenAI API key
- ✅ `default-tenant/credentials/github` - GitHub token

## Security Notes

- ✅ Never commit `.env` files
- ✅ Use placeholders in `.env.example` files
- ✅ Rotate AWS access keys every 90 days
- ✅ Enable MFA on AWS account
- ✅ Use minimal IAM permissions (principle of least privilege)
- ✅ Review GitHub Actions logs for exposed secrets
- ✅ Enable branch protection on `main` branch

## Next Steps

After configuring secrets:

1. [ ] Push code to GitHub
2. [ ] Test CI workflow
3. [ ] Test deployment workflow (manual dispatch)
4. [ ] Create release tag
5. [ ] Monitor first automated deployment
