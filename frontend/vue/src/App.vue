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
      kotlinStatus: 'pending'
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
</style>

