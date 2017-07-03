import Vue from 'vue';
import VueRouter from 'vue-router';

import Add from './add.vue';
import Search from './search.vue';
import Settings from './settings.vue';
import Wrapper from './wrapper.vue';
import store from '@/store';

Vue.use(VueRouter);

const router = new VueRouter({
  el: '#app',
  routes: [
    {path: '/', component: Search},
    {path: '/add', component: Add},
    {path: '/settings', component: Settings},
  ],
});

// If the user isn't authenticated, only show the settings page.
router.beforeEach((to, from, next) => store.hydrate.then(() => {
  if (to.path !== '/settings' && !store.state.token) {
    next('/settings');
  }
  else {
    next();
  }
}));

new Vue({
  el: '#app',
  render: h => h(Wrapper),
  router,
  store,
});
