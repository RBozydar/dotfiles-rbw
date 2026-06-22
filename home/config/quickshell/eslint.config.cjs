const js = require("@eslint/js");
const globals = require("globals");

module.exports = [
    {
        ignores: [
            "node_modules/**",
            ".review/**",
            ".venv/**",
            ".mypy_cache/**",
            ".pytest_cache/**",
            ".ruff_cache/**",
            "uv.lock",
        ],
    },
    {
        files: ["services/**/*.js", "system/**/*.js"],
        languageOptions: {
            ecmaVersion: 2024,
            sourceType: "script",
            globals: {
                ...globals.es2024,
            },
        },
        rules: {
            ...js.configs.recommended.rules,
            "no-console": "off",
            "no-unused-vars": "off",
        },
    },
    {
        files: ["scripts/**/*.js", "*.config.cjs"],
        languageOptions: {
            ecmaVersion: 2024,
            sourceType: "commonjs",
            globals: {
                ...globals.node,
            },
        },
        rules: {
            ...js.configs.recommended.rules,
            "no-console": "off",
            "no-unused-vars": "off",
        },
    },
];
