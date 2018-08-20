package twa.siedelwood.s5.questeditor.models.parameter;

/**
 * Paramater interface
 * @author totalwarANGEL
 */
public interface Parameter
{
	/**
	 * Returns the name of the parameter.
	 * @return Type of parameter
	 */
	public String getType();
	
	/**
	 * Returns the value of the parameter.
	 * @return Value of paramater
	 */
	public Object getValue();
	
	/**
	 * Returns the name of the parameter.
	 * @param type Type of paramater
	 */
	public void setType(String type);
	
	/**
	 * Returns the value of the parameter.
	 * @param value Value of parameter
	 */
	public void setValue(Object value);
}
