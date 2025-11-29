const { defineConfig } = require('@vue/cli-service')

module.exports = defineConfig({
  transpileDependencies: true,
  devServer: {
    host: '0.0.0.0',
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://backend-springboot:8080',
        changeOrigin: true,
        pathRewrite: {
          '^/api/kotlin': '/api/kotlin'
        }
      }
    }
  }
})

