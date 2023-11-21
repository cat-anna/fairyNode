<template>
  <Bubble :options="chartOptions" :data="props.chartData" />
</template>

<script setup lang="ts">
  import { Bubble } from 'vue-chartjs'
  import { Chart as ChartJS, Title, Tooltip, Legend, PointElement, LinearScale, ChartOptions } from 'chart.js'
  import { TBubbleChartData } from '../../../data/types'

  ChartJS.register(Title, Tooltip, Legend, PointElement, LinearScale)

  const props = defineProps<{
    chartData: TBubbleChartData
    chartOptions?: ChartOptions<'bubble'>
  }>()
</script>
