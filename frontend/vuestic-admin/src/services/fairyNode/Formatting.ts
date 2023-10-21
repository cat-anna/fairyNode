

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
}

export default new Formatting();
