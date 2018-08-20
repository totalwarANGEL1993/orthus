package twa.siedelwood.s5.questeditor.models.parameter;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;

@Setter
@Getter
@AllArgsConstructor
public class StringParameterImpl implements StringParamater
{
	protected String type;
	
	protected String value;

	@Override
	public void setValue(final Object value)
	{
		this.value = (String) value;
	}
}
