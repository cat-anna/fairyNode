import { ChartSeriesValueEntry } from './PropertyService'


export interface ChartPoint {
    x: any
    y: any
};

class Formatting {

    public formatSeconds(duration: number): string {
        if (duration == null) {
            return "&lt;?&gt;"
        }

        var hours = Math.floor(duration / 3600);
        var minutes = Math.floor((duration - (hours * 3600)) / 60);
        var seconds = duration - (hours * 3600) - (minutes * 60);
        var days = Math.floor(hours / 24);
        hours = hours - days * 24;

        var str_days = this.pad(Math.round(days).toString(), 3)
        var str_hours = this.pad(Math.round(hours).toString(), 2)
        var str_minutes = this.pad(Math.round(minutes).toString(), 2)
        var str_seconds = this.pad(Math.round(seconds).toString(), 2)

        return str_days + "d " + str_hours + ':' + str_minutes + ':' + str_seconds;
    }

    public formatTimestamp(timestamp: number): string {
        if (!timestamp) {
            return ""
        }
        return new Date(timestamp * 1000).toLocaleString()
    }

    public pad(num: string, size: number): string {
        while (num.length < size) num = "0" + num;
        return num;
    }

    public transformChartSeries(list: ChartSeriesValueEntry[]) : ChartPoint[] {
        var r = new Array<ChartPoint>()
        for (var key in list) {
            var item = list[key]
            // if (chart.last_timestamp < item.timestamp) {
                // chart.config.data.labels.push(newDate(item.timestamp));
                r.push({
                    // x: Math.round(item.timestamp),//* 1000,
                    x: item.timestamp * 1000,
                    //  moment.unix(item.timestamp).toDate(),
                     //newDate(item.timestamp),
                    y: item.value,
                });
                // chart.last_timestamp = item.timestamp
            // }
        }
        return r
    }
}

export default new Formatting();
