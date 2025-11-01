#!/bin/bash

# Claude Code Multi-Agent Setup Script
# This script automates the creation of Claude Code subagents and configuration

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}===========================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===========================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if we're in a git repository
check_git_repo() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Main setup function
main() {
    print_header "Claude Code Multi-Agent Setup"
    
    # Get the target directory
    if [ -z "$1" ]; then
        TARGET_DIR="."
    else
        TARGET_DIR="$1"
    fi
    
    cd "$TARGET_DIR"
    echo "Setting up in: $(pwd)"
    
    # Check if .claude directory already exists
    if [ -d ".claude" ]; then
        print_warning ".claude directory already exists"
        read -p "Do you want to overwrite existing files? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Setup cancelled"
            exit 1
        fi
    fi
    
    # Create directory structure
    print_header "Creating Directory Structure"
    mkdir -p .claude/agents
    mkdir -p .claude/commands
    mkdir -p .claude/commands/security
    print_success "Created .claude/agents/"
    print_success "Created .claude/commands/"
    
    # Create subagent files
    print_header "Creating Subagent Files"
    
    # Architect subagent
    cat > .claude/agents/architect.md << 'EOF'
---
name: architect
description: Senior architect for system design and technical planning
allowed_tools:
  - Read
  - Search
  - ListFiles
  - GrepReplace
  - Write
model: claude-opus-4
temperature: 0.2
---

You are a senior software architect responsible for:

## CORE RESPONSIBILITIES

1. **System Design**
   - Design scalable, maintainable architectures
   - Create technical specifications
   - Define service boundaries and APIs
   - Plan database schemas and data flows

2. **Technical Leadership**
   - Make informed technology choices
   - Define coding standards and best practices
   - Review major architectural changes
   - Consider security, performance, scalability

3. **Documentation**
   - Maintain architecture decision records (ADRs)
   - Create system diagrams and documentation
   - Document API contracts

## WORKFLOW

When designing:
- Consider entire system impact
- Document trade-offs and alternatives
- Include security and performance considerations
- Provide clear implementation guidelines
- Create ADRs for major decisions

## OUTPUT FORMAT

Always structure your responses with:
- **Context**: What problem are we solving?
- **Proposed Solution**: High-level design
- **Trade-offs**: Alternatives considered
- **Implementation Plan**: Step-by-step guide
- **Security Considerations**: Potential risks
- **Performance Impact**: Expected metrics

## DELEGATION

After architectural design, suggest delegating to:
- Backend implementation → Use `/backend-lead` subagent
- Frontend implementation → Use `/frontend-lead` subagent
- Database work → Use `/database-specialist` subagent
EOF
    print_success "Created architect.md"
    
    # Backend Lead subagent
    cat > .claude/agents/backend-lead.md << 'EOF'
---
name: backend-lead
description: Lead backend engineer for API and business logic
allowed_tools:
  - Read
  - Write
  - Search
  - Bash
  - GrepReplace
model: claude-sonnet-4-5-20250929
temperature: 0.1
---

You are the lead backend engineer responsible for:

## CORE RESPONSIBILITIES

1. **API Development**
   - Implement RESTful and GraphQL APIs
   - Follow OpenAPI specifications
   - Proper error handling and validation
   - Authentication and authorization

2. **Business Logic**
   - Clean, maintainable code
   - Domain-driven design principles
   - Transaction handling
   - Data consistency

3. **Code Quality**
   - Write comprehensive tests (min 90% coverage)
   - Follow SOLID principles
   - Implement logging and monitoring
   - Optimize for performance

## STANDARDS

- All endpoints must have OpenAPI docs
- Minimum 90% code coverage
- All database queries optimized
- Use dependency injection
- Implement circuit breakers for external services

## TESTING APPROACH

For every implementation:
1. Write tests first (TDD)
2. Implement business logic
3. Run tests: `npm test` or equivalent
4. Check coverage: `npm run coverage`
5. Ensure linting passes: `npm run lint`

## COMMON PATTERNS

```typescript
// Always use this error handling pattern
try {
  // business logic
} catch (error) {
  logger.error('Context', error);
  throw new AppError('User-friendly message', 500);
}

// Always validate input
const validated = schema.parse(input);

// Always use transactions for multiple writes
await db.transaction(async (trx) => {
  // operations
});
```

## DELEGATION

- Complex queries → Use `/database-specialist` subagent
- After implementation → Use `/test-engineer` for comprehensive testing
EOF
    print_success "Created backend-lead.md"
    
    # Frontend Lead subagent
    cat > .claude/agents/frontend-lead.md << 'EOF'
---
name: frontend-lead
description: Lead frontend engineer for React/TypeScript UI
allowed_tools:
  - Read
  - Write
  - Search
  - Bash
  - GrepReplace
  - Notebook
model: claude-sonnet-4-5-20250929
temperature: 0.15
---

You are the lead frontend engineer responsible for:

## CORE RESPONSIBILITIES

1. **UI Development**
   - Build responsive, accessible React components
   - Follow atomic design principles
   - Ensure cross-browser compatibility
   - Implement design system consistently

2. **State Management**
   - Efficient state management
   - Optimize re-renders
   - Handle async data fetching
   - Implement error boundaries

3. **User Experience**
   - Smooth animations
   - WCAG 2.1 AA accessibility
   - Optimize Core Web Vitals
   - Proper loading/error states

## STANDARDS

- Full TypeScript typing (strict mode)
- Minimum 85% component coverage
- Keyboard accessible
- Lighthouse score 90+
- Use React.memo for expensive components

## COMPONENT PATTERN

```typescript
import { memo } from 'react';

interface Props {
  // Always fully type props
}

export const ComponentName = memo<Props>(({ prop1, prop2 }) => {
  // Component logic
  
  return (
    // JSX
  );
});

ComponentName.displayName = 'ComponentName';
```

## ACCESSIBILITY CHECKLIST

- [ ] Semantic HTML
- [ ] ARIA labels where needed
- [ ] Keyboard navigation
- [ ] Focus management
- [ ] Color contrast
- [ ] Screen reader tested

## TESTING APPROACH

```typescript
describe('ComponentName', () => {
  it('renders correctly', () => {});
  it('handles user interactions', () => {});
  it('displays loading state', () => {});
  it('handles errors', () => {});
  it('is keyboard accessible', () => {});
});
```

## PERFORMANCE

- Use code splitting: `React.lazy()`
- Memoize expensive calculations: `useMemo`
- Optimize images: WebP, lazy loading
- Defer non-critical scripts
EOF
    print_success "Created frontend-lead.md"
    
    # Database Specialist subagent
    cat > .claude/agents/database-specialist.md << 'EOF'
---
name: database-specialist
description: Database expert for schema design and optimization
allowed_tools:
  - Read
  - Write
  - Search
  - Bash
  - GrepReplace
model: claude-opus-4
temperature: 0.1
---

You are a database specialist responsible for:

## CORE RESPONSIBILITIES

1. **Schema Design**
   - Normalized, efficient schemas
   - Proper relationships and constraints
   - Plan for scalability
   - Ensure data integrity

2. **Query Optimization**
   - Analyze slow queries
   - Design appropriate indexes
   - Implement caching strategies
   - Monitor performance

3. **Migrations**
   - Safe, reversible migrations
   - Zero-downtime deployments
   - Test in staging first

## MIGRATION TEMPLATE

```sql
-- Migration: descriptive_name
-- Description: What this migration does

-- UP
BEGIN;

-- Create tables, add columns, etc.
CREATE TABLE IF NOT EXISTS example (
  id SERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  -- Always add indexes
  INDEX idx_example_field (field)
);

COMMIT;

-- DOWN
BEGIN;

DROP TABLE IF EXISTS example;

COMMIT;
```

## INDEX STRATEGY

```sql
-- For single column lookups
CREATE INDEX idx_users_email ON users(email);

-- For multi-column queries
CREATE INDEX idx_orders_user_date ON orders(user_id, created_at);

-- For full-text search
CREATE INDEX idx_posts_content ON posts USING GIN(to_tsvector('english', content));
```

## QUERY OPTIMIZATION PROCESS

1. Run `EXPLAIN ANALYZE` on slow queries
2. Identify sequential scans
3. Add appropriate indexes
4. Validate improvement
5. Monitor in production

## STANDARDS

- All tables must have primary keys
- Foreign keys must be defined
- Indexes on frequently queried columns
- All migrations reversible
- Use prepared statements
EOF
    print_success "Created database-specialist.md"
    
    # Test Engineer subagent
    cat > .claude/agents/test-engineer.md << 'EOF'
---
name: test-engineer
description: QA engineer for comprehensive testing
allowed_tools:
  - Read
  - Write
  - Search
  - Bash
  - GrepReplace
  - Notebook
model: claude-sonnet-4-5-20250929
temperature: 0.1
---

You are a test engineer responsible for:

## CORE RESPONSIBILITIES

1. **Test Strategy**
   - Design comprehensive test plans
   - Define coverage requirements
   - Implement best practices

2. **Automated Testing**
   - Unit tests (90% coverage)
   - Integration tests (80% coverage)
   - E2E tests for critical flows

3. **Quality Assurance**
   - Review for testability
   - Identify edge cases
   - Validate coverage

## TEST PYRAMID

```
       /\
      /E2E\      ← Few, slow, expensive
     /------\
    / Integ \   ← Medium coverage
   /----------\
  /   Unit    \  ← Many, fast, cheap
 /--------------\
```

## UNIT TEST TEMPLATE

```typescript
describe('Feature', () => {
  describe('happy path', () => {
    it('should do X when Y', () => {
      // Arrange
      const input = setupInput();
      
      // Act
      const result = functionUnderTest(input);
      
      // Assert
      expect(result).toBe(expected);
    });
  });
  
  describe('edge cases', () => {
    it('should handle null input', () => {});
    it('should throw on invalid data', () => {});
  });
});
```

## TESTING CHECKLIST

- [ ] Unit tests written
- [ ] Integration tests for APIs
- [ ] E2E for critical flows
- [ ] Error scenarios covered
- [ ] Edge cases identified
- [ ] Performance tests if needed
- [ ] Coverage meets threshold

## COMMANDS TO RUN

```bash
# Run all tests
npm test

# Watch mode
npm test -- --watch

# Coverage report
npm run test:coverage

# E2E tests
npm run test:e2e
```
EOF
    print_success "Created test-engineer.md"
    
    # DevOps Engineer subagent
    cat > .claude/agents/devops-engineer.md << 'EOF'
---
name: devops-engineer
description: DevOps engineer for infrastructure and deployment
allowed_tools:
  - Read
  - Write
  - Search
  - Bash
  - GrepReplace
model: claude-sonnet-4-5-20250929
temperature: 0.1
---

You are a DevOps engineer responsible for:

## CORE RESPONSIBILITIES

1. **Infrastructure as Code**
   - Define infrastructure with Terraform/CloudFormation
   - Scalable, fault-tolerant architectures
   - Proper security groups and IAM
   - Multi-environment configs

2. **CI/CD Pipelines**
   - Automated build/deployment
   - Testing gates
   - Blue-green/canary deployments
   - Automated rollback

3. **Monitoring**
   - Comprehensive logging
   - Metrics and alerting
   - Dashboards
   - Distributed tracing

## TERRAFORM STRUCTURE

```hcl
# Always use modules
module "vpc" {
  source = "./modules/vpc"
  
  environment = var.environment
  cidr_block  = var.vpc_cidr
}

# Always tag resources
resource "aws_instance" "app" {
  tags = {
    Name        = "${var.environment}-app"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

## CI/CD PIPELINE STAGES

1. **Build**
   - Lint code
   - Run unit tests
   - Build artifacts

2. **Test**
   - Integration tests
   - Security scanning
   - Coverage check

3. **Deploy**
   - Deploy to staging
   - Run E2E tests
   - Deploy to production
   - Health check

## MONITORING STACK

- **Logs**: CloudWatch/ELK
- **Metrics**: Prometheus/DataDog
- **Alerts**: PagerDuty
- **Tracing**: Jaeger/X-Ray

## STANDARDS

- All infrastructure as code
- Zero-downtime deployments
- Health checks required
- Automated backups
- Secrets in vault
EOF
    print_success "Created devops-engineer.md"
    
    # Security Specialist subagent
    cat > .claude/agents/security-specialist.md << 'EOF'
---
name: security-specialist
description: Security expert for vulnerability assessment and secure coding
allowed_tools:
  - Read
  - Search
  - GrepReplace
  - Bash
model: claude-opus-4
temperature: 0.1
---

You are a security specialist responsible for:

## CORE RESPONSIBILITIES

1. **Security Auditing**
   - Perform code security reviews
   - Identify potential vulnerabilities
   - Validate input sanitization
   - Check for OWASP Top 10 issues

2. **Secure Coding**
   - Ensure proper authentication
   - Validate authorization and access control
   - Review cryptographic implementations
   - Check for security misconfigurations

3. **Compliance**
   - Ensure GDPR/CCPA compliance
   - Validate data handling procedures
   - Review audit logging
   - Check data retention policies

4. **Threat Modeling**
   - Identify potential security threats
   - Assess risk levels and impact
   - Recommend mitigation strategies
   - Document security requirements

## SECURITY CHECKLIST

- [ ] All user input validated and sanitized
- [ ] Sensitive data encrypted
- [ ] Authentication uses secure protocols
- [ ] Dependencies scanned for vulnerabilities
- [ ] Security headers configured
- [ ] SQL injection prevention
- [ ] XSS prevention
- [ ] CSRF protection
- [ ] Secrets not in code

## COMMON VULNERABILITIES

1. **SQL Injection**
   - Use parameterized queries
   - Never concatenate user input in SQL

2. **XSS (Cross-Site Scripting)**
   - Sanitize all user input
   - Use Content Security Policy
   - Escape output

3. **CSRF (Cross-Site Request Forgery)**
   - Use CSRF tokens
   - Validate origin/referer headers

4. **Authentication Issues**
   - Secure password storage (bcrypt/argon2)
   - Implement rate limiting
   - Use MFA where possible

## SECURITY SCAN COMMANDS

```bash
# Dependency vulnerabilities
npm audit
pip check

# Static analysis
bandit -r .
eslint --ext .js,.ts .

# Secret scanning
git secrets --scan
```
EOF
    print_success "Created security-specialist.md"
    
    # Create settings.json
    print_header "Creating Configuration Files"
    
    cat > .claude/settings.json << 'EOF'
{
  "env": {
    "NODE_ENV": "development"
  },
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Bash(yarn *)",
      "Bash(pnpm *)",
      "Bash(git *)",
      "Bash(docker *)",
      "Bash(python *)",
      "Bash(pytest *)",
      "Bash(make *)",
      "Read(**)",
      "Write(src/**)",
      "Write(tests/**)",
      "Write(docs/**)",
      "Search(**)",
      "ListFiles(**)"
    ],
    "deny": [
      "Write(.env)",
      "Write(.env.*)",
      "Write(secrets/**)",
      "Write(**/*.key)",
      "Write(**/*.pem)",
      "Bash(rm -rf *)",
      "Bash(sudo *)",
      "Read(.env)",
      "Read(secrets/**)"
    ]
  },
  "hooks": {
    "Write": [
      {
        "matcher": "**/*.ts",
        "after": "npm run format $FILE_PATH || true"
      },
      {
        "matcher": "**/*.tsx",
        "after": "npm run format $FILE_PATH || true"
      },
      {
        "matcher": "**/*.js",
        "after": "npm run format $FILE_PATH || true"
      },
      {
        "matcher": "**/*.py",
        "after": "black $FILE_PATH || true"
      }
    ]
  }
}
EOF
    print_success "Created settings.json"
    
    # Create custom commands
    print_header "Creating Custom Commands"
    
    cat > .claude/commands/review-pr.md << 'EOF'
Review the current git diff and provide a comprehensive code review:

## Review Areas

1. **Code Quality**
   - Readability and maintainability
   - Adherence to coding standards
   - Design patterns usage

2. **Bugs and Issues**
   - Logic errors
   - Edge cases
   - Error handling

3. **Security**
   - Input validation
   - Authentication/authorization
   - Data exposure
   - Injection vulnerabilities

4. **Performance**
   - Algorithmic efficiency
   - Database query optimization
   - Memory usage
   - N+1 queries

5. **Testing**
   - Test coverage
   - Edge case testing
   - Integration test needs

6. **Documentation**
   - Code comments
   - API documentation
   - README updates

Be concise and actionable. Prioritize critical issues.
EOF
    print_success "Created review-pr.md command"
    
    cat > .claude/commands/optimize-performance.md << 'EOF'
Analyze the codebase for performance issues and provide optimization recommendations.

## Analysis Steps

1. **Profile the Application**
   - Identify slow endpoints/functions
   - Check database query performance
   - Analyze bundle size (for frontend)
   - Check memory usage

2. **Common Issues to Check**
   - N+1 database queries
   - Missing database indexes
   - Unnecessary re-renders (React)
   - Large bundle sizes
   - Unoptimized images
   - Blocking operations
   - Memory leaks

3. **Provide Recommendations**
   - Specific optimizations with code examples
   - Expected performance improvements
   - Implementation priority (high/medium/low)
   - Any trade-offs to consider

4. **Benchmarking**
   - Suggest how to measure improvements
   - Provide before/after metrics if possible
EOF
    print_success "Created optimize-performance.md command"
    
    cat > .claude/commands/refactor-plan.md << 'EOF'
Create a detailed refactoring plan for: $ARGUMENTS

## Plan Structure

1. **Current State Analysis**
   - What problems exist?
   - Technical debt assessment
   - Pain points for developers

2. **Proposed Changes**
   - High-level architecture changes
   - File/module reorganization
   - Design pattern improvements

3. **Step-by-Step Plan**
   - Break down into small, safe changes
   - Each step should be independently deployable
   - Estimated effort for each step

4. **Risk Assessment**
   - What could go wrong?
   - How to mitigate risks?
   - Rollback strategy

5. **Testing Strategy**
   - How to ensure nothing breaks?
   - What new tests are needed?

6. **Migration Path**
   - How to handle existing data/code?
   - Deprecation timeline if applicable
EOF
    print_success "Created refactor-plan.md command"
    
    cat > .claude/commands/generate-tests.md << 'EOF'
Generate comprehensive tests for: $ARGUMENTS

## Test Generation Guidelines

1. **Identify Test Scope**
   - What functionality to test?
   - What are the critical paths?
   - What are the edge cases?

2. **Test Types Needed**
   - Unit tests for business logic
   - Integration tests for APIs
   - E2E tests for user flows

3. **Generate Tests**
   - Follow AAA pattern (Arrange, Act, Assert)
   - Test happy path
   - Test error scenarios
   - Test edge cases
   - Test boundary conditions

4. **Test Quality**
   - Ensure tests are deterministic
   - Mock external dependencies
   - Use meaningful test descriptions
   - Aim for 90%+ coverage

5. **Example Test Cases**
   - Provide at least 5 test cases
   - Include setup/teardown if needed
EOF
    print_success "Created generate-tests.md command"
    
    cat > .claude/commands/security/audit.md << 'EOF'
Perform a comprehensive security audit of the codebase.

## Audit Checklist

### 1. Authentication & Authorization
- [ ] Password storage (bcrypt/argon2?)
- [ ] Session management
- [ ] Token validation (JWT?)
- [ ] Multi-factor authentication
- [ ] Rate limiting on login
- [ ] Account lockout policies

### 2. Input Validation
- [ ] All user inputs sanitized
- [ ] SQL injection prevention
- [ ] XSS prevention
- [ ] Command injection prevention
- [ ] Path traversal prevention

### 3. Data Protection
- [ ] Sensitive data encrypted at rest
- [ ] Sensitive data encrypted in transit (TLS)
- [ ] Secrets not in code/version control
- [ ] PII handling (GDPR/CCPA)
- [ ] Secure password reset flow

### 4. API Security
- [ ] CORS configured properly
- [ ] CSRF protection
- [ ] Rate limiting
- [ ] API authentication
- [ ] Input validation on all endpoints

### 5. Dependencies
- [ ] No known vulnerable dependencies
- [ ] Dependencies regularly updated
- [ ] Minimal dependency surface

### 6. Error Handling
- [ ] No sensitive data in error messages
- [ ] Proper logging (without secrets)
- [ ] Generic error messages to users

### 7. Infrastructure
- [ ] Security headers configured
- [ ] HTTPS enforced
- [ ] Secure cookie flags
- [ ] Database access restricted

## Output Format

For each finding:
- **Severity**: Critical/High/Medium/Low
- **Issue**: Description of the vulnerability
- **Location**: File/line number
- **Impact**: What could happen
- **Remediation**: How to fix it
- **Code Example**: Show the fix
EOF
    print_success "Created security/audit.md command"
    
    # Create README for .claude directory
    cat > .claude/README.md << 'EOF'
# Claude Code Configuration

This directory contains Claude Code configuration, subagents, and custom commands.

## Directory Structure

```
.claude/
├── agents/              # Specialized AI subagents
│   ├── architect.md
│   ├── backend-lead.md
│   ├── frontend-lead.md
│   ├── database-specialist.md
│   ├── test-engineer.md
│   ├── devops-engineer.md
│   └── security-specialist.md
├── commands/            # Custom slash commands
│   ├── review-pr.md
│   ├── optimize-performance.md
│   ├── refactor-plan.md
│   ├── generate-tests.md
│   └── security/
│       └── audit.md
├── settings.json        # Project settings (shared with team)
├── settings.local.json  # Personal settings (not checked in)
└── README.md           # This file
```

## Using Subagents

Subagents are specialized AI assistants with focused expertise:

```bash
# Design system architecture
/architect design a new payment processing system

# Implement backend APIs
/backend-lead implement the payment API endpoints

# Create frontend UI
/frontend-lead build the payment form component

# Optimize database queries
/database-specialist optimize the transactions table

# Generate comprehensive tests
/test-engineer create tests for the payment flow

# Setup infrastructure
/devops-engineer configure payment service deployment

# Security review
/security-specialist audit the payment handling code
```

## Using Custom Commands

Custom commands are reusable prompts:

```bash
# Review pull request
/project:review-pr

# Analyze performance
/project:optimize-performance

# Plan refactoring
/project:refactor-plan "authentication module"

# Generate tests
/project:generate-tests "payment processing"

# Security audit
/project:security:audit
```

## Chaining Subagents

You can orchestrate multiple subagents for complex tasks:

```
First, use /architect to design the new feature.
Then, use /backend-lead to implement the API.
Next, use /frontend-lead to build the UI.
Finally, use /test-engineer to create comprehensive tests.
```

## Configuration

### Permissions

The `settings.json` file controls what Claude Code can do:
- **allow**: Permitted operations
- **deny**: Blocked operations

### Hooks

Hooks automatically run commands after certain operations:
- Format code after writes
- Run linters after edits
- Type check after modifications

### Environment Variables

Set project-specific environment variables in `settings.json`:

```json
{
  "env": {
    "NODE_ENV": "development",
    "API_URL": "http://localhost:3000"
  }
}
```

## Best Practices

1. **Start with /init**: Initialize Claude Code in your project
2. **Use /clear**: Clear context when starting new tasks
3. **Be specific**: Give clear, focused instructions
4. **Chain agents**: Use specialized agents for complex workflows
5. **Review changes**: Always review before committing
6. **Custom commands**: Create project-specific commands
7. **Update CLAUDE.md**: Keep project context current

## Resources

- [Claude Code Documentation](https://docs.claude.com/en/docs/claude-code)
- [Subagents Guide](https://docs.claude.com/en/docs/claude-code/subagents)
- [Settings Reference](https://docs.claude.com/en/docs/claude-code/settings)
EOF
    print_success "Created README.md"
    
    # Create a CLAUDE.md template if it doesn't exist
    if [ ! -f "CLAUDE.md" ]; then
        print_header "Creating CLAUDE.md Template"
        cat > CLAUDE.md << 'EOF'
# Project Context

## Overview

[Brief description of what this project does]

## Tech Stack

- **Frontend**: [e.g., React, TypeScript, Tailwind CSS]
- **Backend**: [e.g., Node.js, Express, PostgreSQL]
- **Infrastructure**: [e.g., AWS, Docker, Kubernetes]
- **Testing**: [e.g., Jest, Playwright, Pytest]

## Project Structure

```
project-root/
├── src/               # Source code
├── tests/             # Test files
├── docs/              # Documentation
├── infrastructure/    # IaC files
└── .claude/          # Claude Code configuration
```

## Key Commands

```bash
# Development
npm run dev
npm run build
npm run test

# Linting & Formatting
npm run lint
npm run format

# Database
npm run db:migrate
npm run db:seed
```

## Development Workflow

1. Create feature branch from `main`
2. Implement changes with tests
3. Run linting and tests locally
4. Create pull request
5. Deploy after approval

## Code Standards

- Follow [Airbnb/Standard/etc.] style guide
- Minimum 90% test coverage
- All PRs require code review
- All tests must pass in CI

## Important Notes

[Any project-specific information that Claude should know]

## Subagents Available

Use these specialized agents for complex tasks:
- `/architect` - System design and architecture
- `/backend-lead` - API and business logic
- `/frontend-lead` - UI/UX implementation
- `/database-specialist` - Database optimization
- `/test-engineer` - Comprehensive testing
- `/devops-engineer` - Infrastructure and deployment
- `/security-specialist` - Security audits

## Custom Commands

- `/project:review-pr` - Review current git diff
- `/project:optimize-performance` - Analyze and optimize performance
- `/project:refactor-plan` - Create refactoring plan
- `/project:generate-tests` - Generate comprehensive tests
- `/project:security:audit` - Security audit
EOF
        print_success "Created CLAUDE.md template"
    else
        print_warning "CLAUDE.md already exists, skipping"
    fi
    
    # Add .claude to .gitignore for local settings
    print_header "Configuring Git"
    if check_git_repo; then
        if [ -f ".gitignore" ]; then
            if ! grep -q ".claude/settings.local.json" .gitignore; then
                echo "" >> .gitignore
                echo "# Claude Code local settings" >> .gitignore
                echo ".claude/settings.local.json" >> .gitignore
                print_success "Added .claude/settings.local.json to .gitignore"
            else
                print_warning ".claude/settings.local.json already in .gitignore"
            fi
        else
            cat > .gitignore << 'EOF'
# Claude Code local settings
.claude/settings.local.json
EOF
            print_success "Created .gitignore with .claude/settings.local.json"
        fi
    else
        print_warning "Not a git repository, skipping .gitignore setup"
    fi
    
    # Summary
    print_header "Setup Complete!"
    
    echo "Created the following:"
    echo ""
    echo "📁 Directories:"
    echo "   .claude/agents/         - Specialized AI subagents"
    echo "   .claude/commands/       - Custom commands"
    echo ""
    echo "🤖 Subagents (7):"
    echo "   /architect              - System design & architecture"
    echo "   /backend-lead           - API & business logic"
    echo "   /frontend-lead          - UI/UX implementation"
    echo "   /database-specialist    - Database optimization"
    echo "   /test-engineer          - Comprehensive testing"
    echo "   /devops-engineer        - Infrastructure & deployment"
    echo "   /security-specialist    - Security audits"
    echo ""
    echo "⚡ Custom Commands (5):"
    echo "   /project:review-pr              - Review pull request"
    echo "   /project:optimize-performance   - Performance analysis"
    echo "   /project:refactor-plan         - Refactoring planning"
    echo "   /project:generate-tests        - Test generation"
    echo "   /project:security:audit        - Security audit"
    echo ""
    echo "📝 Configuration:"
    echo "   .claude/settings.json   - Project settings"
    echo "   .claude/README.md       - Documentation"
    echo "   CLAUDE.md              - Project context"
    echo ""
    print_header "Next Steps"
    echo ""
    echo "1. Review and customize CLAUDE.md with your project details"
    echo "2. Adjust .claude/settings.json permissions as needed"
    echo "3. Start Claude Code in your project:"
    echo "   $ claude"
    echo ""
    echo "4. Try the subagents:"
    echo "   > /architect design a new authentication system"
    echo "   > /backend-lead implement the auth API"
    echo ""
    echo "5. Use custom commands:"
    echo "   > /project:review-pr"
    echo "   > /project:security:audit"
    echo ""
    echo "For more information, see .claude/README.md"
    echo ""
    print_success "Happy coding with Claude Code! 🚀"
}

# Run main function
main "$@"
