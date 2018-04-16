function [p1,p2] = lineCircleIntersection(m,c,center,r)
    [p1] = [-Inf -Inf];
    [p2] = [-Inf -Inf];
    
    disc = r^2*(1+m^2) - (center(2)-m*center(1)-center(2))^2;
    if disc < 0
        return
    end

    p1(1) = (center(1)+center(2)*m-c*m+sqrt(disc))/(1+m^2);
    p2(1) = (center(1)+center(2)*m-c*m-sqrt(disc))/(1+m^2);

    p1(2) = m*p1(1)+c;
    p2(2) = m*p2(1)+c;
end
