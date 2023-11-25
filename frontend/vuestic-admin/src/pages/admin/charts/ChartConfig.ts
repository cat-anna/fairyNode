import { ChartOptions } from 'chart.js'

export const chartConfig: ChartOptions<'line'> = {
  maintainAspectRatio: false,
  animation: {
    loop: false,
  },

  plugins: {
    legend: {
      position: 'bottom',
      labels: {
        font: {
          // @ts-ignore
          color: '#34495e',
          family: 'sans-serif',
          size: 14,
        },
        usePointStyle: true,
      },
    },
    tooltip: {
      bodyFont: {
        size: 14,
        family: 'sans-serif',
      },
      boxPadding: 4,
    },
  },
  elements: {
    point: {
      radius: 2,
      hoverRadius: 5,
    },
  },
  scales: {
    x: {
      // @ts-ignore
      type: 'time',
      time: {},
      ticks: {
        // @ts-ignore
        fontColor: 'rgb(150, 150, 150)',
        maxTicksLimit: 10,
      },
      scaleLabel: {
        fontColor: 'rgb(150, 150, 150)',
        display: true,
      },
    },
    y: {
      // @ts-ignore
      type: 'linear',
      // min: 0,
      // max: 2000,
      ticks: {
        // @ts-ignore
        fontColor: 'rgb(150, 150, 150)',
      },
      scaleLabel: {
        fontColor: 'rgb(150, 150, 150)',
        display: true,
        labelString: 'value',
      },
    },
  },
}
