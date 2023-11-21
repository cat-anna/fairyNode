<template>
  <Pie :options="chartOptions" :data="props.chartData" />
</template>

<script setup lang="ts">
  import { Pie } from 'vue-chartjs'
  import { Chart as ChartJS, Title, Tooltip, Legend, ArcElement, CategoryScale, ChartOptions } from 'chart.js'
  import { TPieChartData } from '../../../data/types'

  ChartJS.register(Title, Tooltip, Legend, ArcElement, CategoryScale)

  const props = defineProps<{
    chartData: TPieChartData
    chartOptions?: ChartOptions<'pie'>
  }>()
</script>
