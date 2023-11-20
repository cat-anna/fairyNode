<template>
  <div class="dashboard">
    <dashboard-device-table />
  </div>
</template>

<script setup lang="ts">
  import DashboardDeviceTable from './DashboardDeviceTable.vue'
</script>

<style lang="scss">
  .dashboard {
    .va-card {
      margin-bottom: 0 !important;
      &__title {
        display: flex;
        justify-content: space-between;
      }
    }
  }
</style>
