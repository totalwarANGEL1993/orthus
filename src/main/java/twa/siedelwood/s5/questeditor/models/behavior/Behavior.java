
package twa.siedelwood.s5.questeditor.models.behavior;

import java.util.List;
import twa.siedelwood.s5.questeditor.models.parameter.Parameter;

/**
 * Behavior Interface
 * 
 * @author totalwarANGEL
 *
 */
public interface Behavior
{
	/**
	 * Returns the Type of the behavior.
	 * 
	 * @return Type
	 */
	public String getType();

	/**
	 * Returns the name of the behavior.
	 * 
	 * @return Name
	 */
	public String getName();

	/**
	 * Returns the argument list of the behavior.
	 * 
	 * @return List of arguments
	 */
	public List<Parameter> getArguments();
	
	/**
	 * Sets the Type of the behavior.
	 * 
	 * @param type Type of behavior
	 */
	public void setType(String type);

	/**
	 * Sets the name of the behavior.
	 * 
	 * @param name Name of behavior
	 */
	public void setName(String name);

	/**
	 * Sets the argument list of the behavior.
	 * 
	 * @param param List of arguments
	 */
	public void setArguments(List<Parameter> param);
}
