const { defineConfig } = require('@vue/cli-service')

module.exports = defineConfig({
  transpileDependencies: true,
  devServer: {
    host: '0.0.0.0',
    port: 3000,
    proxy: {
      // Kotlin API는 별도 프록시 설정
      '/api/kotlin': {
        target: 'http://backend-kotlin:8081',
        changeOrigin: true,
        ws: true,
        pathRewrite: {
          '^/api/kotlin': '/api/kotlin'
        }
      },
      // Spring Boot API
      '/api': {
        target: 'http://backend-springboot:8080',
        changeOrigin: true,
        ws: true
      }
    }
  }
})

