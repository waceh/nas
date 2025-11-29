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
        ws: true,
        pathRewrite: {
          // /api/kotlin/* 요청은 Kotlin 백엔드로
          '^/api/kotlin': '/api/kotlin'
        },
        // /api/kotlin이 아닌 경우 Spring Boot로, /api/kotlin인 경우 Kotlin으로 라우팅
        router: function(req) {
          if (req.url.startsWith('/api/kotlin')) {
            return 'http://backend-kotlin:8081'
          }
          return 'http://backend-springboot:8080'
        }
      }
    }
  }
})

