class DataTypes {

    public parseBooleanProperty(value: string): boolean {
        if(value == "true")
            return true
        else
            return false
    }
}

export default new DataTypes();
