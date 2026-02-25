module.exports = {
  "*.sol": ["prettier --write", "solhint --fix"],
  "*.ts": ["prettier --write", "eslint --fix"],
  "*.json": ["prettier --write"],
  "*.md": ["prettier --write"],
};