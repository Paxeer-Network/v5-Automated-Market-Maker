## Description

<!-- Brief description of the changes -->

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Contract upgrade (changes to Solidity code)
- [ ] Documentation update
- [ ] CI/tooling change

## Checklist

### General
- [ ] My code follows the project style guidelines
- [ ] I have performed a self-review of my code
- [ ] I have added tests that prove my fix is effective or my feature works
- [ ] New and existing tests pass locally (`npm test` and `forge test`)

### Smart Contracts (if applicable)
- [ ] Solidity linting passes (`npm run lint:sol`)
- [ ] Contract sizes are within limits (`npm run size`)
- [ ] No new Slither findings (`npm run slither`)
- [ ] Gas usage is reasonable (`npm run test:gas`)
- [ ] Reentrancy guards are in place for external calls
- [ ] Events are emitted for state changes

### Security Considerations
- [ ] No hardcoded secrets or private keys
- [ ] Access control is properly enforced
- [ ] Integer overflow/underflow is handled
- [ ] Flash loan attack vectors are considered
