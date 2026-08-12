<template>
  <div id="app">
    <header>
      <h1>NAS Frontend</h1>
    </header>
    <main>
      <div class="container">
        <section class="status-section">
          <h2>서비스 상태</h2>
          <div class="status-grid">
            <div class="status-card">
              <h3>Spring Boot Backend</h3>
              <p :class="springBootStatus">{{ springBootMessage }}</p>
              <button @click="checkSpringBoot">확인</button>
            </div>
            <div class="status-card">
              <h3>Kotlin Backend</h3>
              <p :class="kotlinStatus">{{ kotlinMessage }}</p>
              <button @click="checkKotlin">확인</button>
            </div>
          </div>
        </section>

        <section class="api-section">
          <h2>API 테스트</h2>
          <div class="api-grid">
            <div class="api-card">
              <h3>Spring Boot API - Users</h3>
              <button @click="fetchUsers" :disabled="loadingUsers">
                {{ loadingUsers ? '로딩 중...' : '사용자 조회' }}
              </button>
              <div v-if="users.length > 0" class="data-display">
                <p class="data-count">총 {{ users.length }}명</p>
                <div class="data-list">
                  <div v-for="user in users" :key="user.id" class="data-item">
                    <strong>{{ user.username }}</strong> - {{ user.email }}
                  </div>
                </div>
              </div>
              <div v-if="usersError" class="error-message">
                {{ usersError }}
              </div>
            </div>

            <div class="api-card">
              <h3>Kotlin API - Products</h3>
              <button @click="fetchProducts" :disabled="loadingProducts">
                {{ loadingProducts ? '로딩 중...' : '제품 조회' }}
              </button>
              <div v-if="products.length > 0" class="data-display">
                <p class="data-count">총 {{ products.length }}개</p>
                <div class="data-list">
                  <div v-for="product in products" :key="product.id" class="data-item">
                    <strong>{{ product.name }}</strong> - {{ formatPrice(product.price) }}원
                    <br>
                    <small>{{ product.description }}</small>
                  </div>
                </div>
              </div>
              <div v-if="productsError" class="error-message">
                {{ productsError }}
              </div>
            </div>
          </div>
        </section>
      </div>
    </main>
  </div>
</template>

<script>
import axios from 'axios'

export default {
  name: 'App',
  data() {
    return {
      springBootMessage: '확인 안됨',
      kotlinMessage: '확인 안됨',
      springBootStatus: 'pending',
      kotlinStatus: 'pending',
      users: [],
      products: [],
      loadingUsers: false,
      loadingProducts: false,
      usersError: null,
      productsError: null
    }
  },
  methods: {
    async checkSpringBoot() {
      try {
        const response = await axios.get('/api/health')
        this.springBootMessage = `${response.data.service} - ${response.data.status}`
        this.springBootStatus = 'success'
      } catch (error) {
        this.springBootMessage = '연결 실패'
        this.springBootStatus = 'error'
      }
    },
    async checkKotlin() {
      try {
        const response = await axios.get('/api/kotlin/health')
        this.kotlinMessage = `${response.data.service} - ${response.data.status}`
        this.kotlinStatus = 'success'
      } catch (error) {
        this.kotlinMessage = '연결 실패'
        this.kotlinStatus = 'error'
      }
    },
    async fetchUsers() {
      this.loadingUsers = true
      this.usersError = null
      try {
        const response = await axios.get('/api/users')
        if (response.data.success) {
          this.users = response.data.data
        } else {
          this.usersError = '데이터 조회 실패'
        }
      } catch (error) {
        this.usersError = `오류: ${error.response?.data?.error || error.message}`
        console.error('Users API Error:', error)
      } finally {
        this.loadingUsers = false
      }
    },
    async fetchProducts() {
      this.loadingProducts = true
      this.productsError = null
      try {
        const response = await axios.get('/api/kotlin/products')
        if (response.data.success) {
          this.products = response.data.data
        } else {
          this.productsError = '데이터 조회 실패'
        }
      } catch (error) {
        this.productsError = `오류: ${error.response?.data?.error || error.message}`
        console.error('Products API Error:', error)
      } finally {
        this.loadingProducts = false
      }
    },
    formatPrice(price) {
      if (!price) return '0'
      return new Intl.NumberFormat('ko-KR').format(price)
    }
  }
}
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
  background: #f5f5f5;
}

#app {
  min-height: 100vh;
}

header {
  background: #2c3e50;
  color: white;
  padding: 2rem;
  text-align: center;
}

header h1 {
  font-size: 2rem;
}

main {
  padding: 2rem;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
}

.status-section h2 {
  margin-bottom: 1.5rem;
  color: #2c3e50;
}

.status-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 1.5rem;
}

.status-card {
  background: white;
  padding: 1.5rem;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.status-card h3 {
  margin-bottom: 1rem;
  color: #34495e;
}

.status-card p {
  margin-bottom: 1rem;
  padding: 0.5rem;
  border-radius: 4px;
}

.status-card p.pending {
  background: #ecf0f1;
  color: #7f8c8d;
}

.status-card p.success {
  background: #d4edda;
  color: #155724;
}

.status-card p.error {
  background: #f8d7da;
  color: #721c24;
}

.status-card button {
  background: #3498db;
  color: white;
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.9rem;
}

.status-card button:hover {
  background: #2980b9;
}

.api-section {
  margin-top: 3rem;
}

.api-section h2 {
  margin-bottom: 1.5rem;
  color: #2c3e50;
}

.api-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
  gap: 1.5rem;
}

.api-card {
  background: white;
  padding: 1.5rem;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.api-card h3 {
  margin-bottom: 1rem;
  color: #34495e;
}

.api-card button {
  background: #27ae60;
  color: white;
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.9rem;
  margin-bottom: 1rem;
}

.api-card button:hover:not(:disabled) {
  background: #229954;
}

.api-card button:disabled {
  background: #95a5a6;
  cursor: not-allowed;
}

.data-display {
  margin-top: 1rem;
}

.data-count {
  font-weight: bold;
  color: #27ae60;
  margin-bottom: 0.5rem;
}

.data-list {
  max-height: 300px;
  overflow-y: auto;
}

.data-item {
  padding: 0.75rem;
  margin-bottom: 0.5rem;
  background: #f8f9fa;
  border-radius: 4px;
  border-left: 3px solid #3498db;
}

.data-item strong {
  color: #2c3e50;
}

.data-item small {
  color: #7f8c8d;
  display: block;
  margin-top: 0.25rem;
}

.error-message {
  margin-top: 1rem;
  padding: 0.75rem;
  background: #f8d7da;
  color: #721c24;
  border-radius: 4px;
  border-left: 3px solid #dc3545;
}
</style>

