
import {
    Chart as ChartJS,
    Title,
    Tooltip,
    Legend,
    LineElement,
    LinearScale,
    PointElement,
    CategoryScale,
    Filler,
    TimeScale,
    Colors
} from 'chart.js'

import 'chartjs-adapter-luxon'

ChartJS.register(
    Colors,
    TimeScale,
    Title,
    Tooltip,
    Legend,
    LineElement,
    LinearScale,
    PointElement,
    CategoryScale,
    Filler
)

// import { Line } from 'vue-chartjs'


