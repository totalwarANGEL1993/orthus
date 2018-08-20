package twa.siedelwood.s5.questeditor.models.parameter;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@AllArgsConstructor
public class NumberParameterImpl implements NumberParamater
{
	protected String type;
	
	protected Number value;

	@Override
	public void setValue(final Object value)
	{
		this.value = (Number) value;
	}
}
